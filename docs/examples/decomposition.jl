using Dates
using HiGHS
using JuMP
using PowerSimulations
using PowerSimulationsDecomposition
using PowerSystemCaseBuilder
using PowerSystems

# Load forecast data; the fixture's reserve services are not modeled in this example.
sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)
area_to_subsystem = Dict("Area1" => "a", "Area2" => "b")

# Create named membership groups, not independent copies of the System.
for subsystem in ("a", "b")
    add_subsystem!(sys, subsystem)
end
# Assign areas and buses separately: area membership does not propagate to buses.
for area in get_components(Area, sys)
    add_component_to_subsystem!(sys, area_to_subsystem[get_name(area)], area)
end
for bus in get_components(ACBus, sys)
    add_component_to_subsystem!(sys, area_to_subsystem[get_name(get_area(bus))], bus)
end
# Keep each generator/load in the same subsystem as its attached bus.
for device in get_components(StaticInjection, sys)
    subsystem = area_to_subsystem[get_name(get_area(get_bus(device)))]
    add_component_to_subsystem!(sys, subsystem, device)
end
# Choose from-bus ownership for AC branches without changing their flow direction.
for branch in get_components(ACTransmission, sys)
    from_bus = get_from(get_arc(branch))
    subsystem = area_to_subsystem[get_name(get_area(from_bus))]
    add_component_to_subsystem!(sys, subsystem, branch)
end

# Configure regional dispatch models; this formulation does not perform unit commitment.
template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, Line, StaticBranch)
set_device_model!(template, MonitoredLine, StaticBranch)

# Solve a 24-hour window at hourly resolution, using HiGHS in each region.
problem = DecisionModel(
    MultiRegionProblem,
    template,
    sys;
    name="RegionalDispatch",
    horizon=Hour(24),
    interval=Hour(1),
    resolution=Hour(1),
    optimizer=optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false),
)
# Build into temporary storage and require successful statuses before reading values.
output_dir = mktempdir()
@assert build!(problem; output_dir=output_dir) == PowerSimulations.ModelBuildStatus.BUILT
@assert solve!(problem) == PowerSimulations.RunStatus.SUCCESSFULLY_FINALIZED

# Read joined regional dispatch with a typed key; standalone string lookup is incomplete.
results = OptimizationProblemResults(problem)
dispatch = read_variable(
    results,
    ActivePowerVariable,
    ThermalStandard;
    table_format=TableFormat.WIDE,
)
# Check every thermal generator and hourly row, allowing only numerical feasibility noise.
generator_names = sort!([get_name(g) for g in get_components(ThermalStandard, sys)])
@assert size(dispatch, 1) == 24
@assert sort!(filter(!=("DateTime"), names(dispatch))) == generator_names
dispatch_values = Matrix(dispatch[:, generator_names])
@assert all(isfinite, dispatch_values)
@assert minimum(dispatch_values) >= -1e-6
println("Solved two regional dispatch models; checked 24 rows and all thermal generators.")
