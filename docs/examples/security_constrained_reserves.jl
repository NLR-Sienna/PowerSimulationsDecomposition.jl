using Dates
using HiGHS
using JuMP
import InfrastructureSystems as IS
using PowerSimulations
using PowerSimulationsDecomposition
using PowerSystemCaseBuilder
using PowerSystems

"""
    assign_example_subsystems!(sys::System, area_to_subsystem::Dict{String, String})

Assign areas, buses, injections, and AC branches using this example's from-bus policy.
"""
function assign_example_subsystems!(sys::System, area_to_subsystem::Dict{String, String})
    for subsystem in unique(collect(values(area_to_subsystem)))
        add_subsystem!(sys, subsystem)
    end
    # Area membership does not propagate to buses or their attached devices.
    for area in get_components(Area, sys)
        add_component_to_subsystem!(sys, area_to_subsystem[get_name(area)], area)
    end
    for bus in get_components(ACBus, sys)
        subsystem = area_to_subsystem[get_name(get_area(bus))]
        add_component_to_subsystem!(sys, subsystem, bus)
    end
    for device in get_components(StaticInjection, sys)
        subsystem = area_to_subsystem[get_name(get_area(get_bus(device)))]
        add_component_to_subsystem!(sys, subsystem, device)
    end
    # Ownership selects the regional model; it does not reverse branch flow signs.
    for branch in get_components(ACTransmission, sys)
        subsystem = area_to_subsystem[get_name(get_area(get_from(get_arc(branch))))]
        add_component_to_subsystem!(sys, subsystem, branch)
    end
    return
end

"""
    make_outage_specifications(sys::System)

Describe each generator outage, responding reserve, and explicit monitored branch set.
"""
function make_outage_specifications(sys::System)
    specifications = @NamedTuple{
        outage_generators::Vector{String},
        responding_reserves::Dict{DataType, String},
        monitored_components::Vector{String},
    }[]
    for (subsystem, generator_name, reserve_name) in
        (("a", "Sundance_1", "Reserve1_1"), ("b", "Sundance_2", "Reserve1_2"))
        # All regional branches are eligible here: both types are modeled without filters.
        monitored_branches =
            collect(get_components(ACTransmission, sys; subsystem_name=subsystem))
        @assert all(get_available, monitored_branches)
        @assert all(
            (branch::ACTransmission) -> branch isa Union{Line, MonitoredLine},
            monitored_branches,
        )
        @assert !isempty(monitored_branches)
        push!(
            specifications,
            (
                outage_generators=[generator_name],
                responding_reserves=Dict{DataType, String}(
                    VariableReserve{ReserveUp} => reserve_name,
                ),
                monitored_components=get_name.(monitored_branches),
            ),
        )
    end
    return specifications
end

"""
    add_outages_to_systems!(systems::Vector{System}, outage_specifications)

Resolve each specification in each System and attach its outage to generators and reserves.
"""
function add_outages_to_systems!(
    systems::Vector{System},
    outage_specifications::Vector{
        @NamedTuple{
            outage_generators::Vector{String},
            responding_reserves::Dict{DataType, String},
            monitored_components::Vector{String},
        }
    },
)
    for specification in outage_specifications
        for sys in systems
            # Resolve objects per System: names can match even when component UUIDs differ.
            monitored_components = [
                get_component(ACTransmission, sys, name) for
                name in specification.monitored_components
            ]
            @assert !isempty(monitored_components)
            @assert all(
                (component::Union{Nothing, ACTransmission}) -> !isnothing(component),
                monitored_components,
            )
            outage = GeometricDistributionForcedOutage(;
                mean_time_to_recovery=10.0,
                outage_transition_probability=1.0,
                monitored_components=monitored_components,
            )
            for generator_name in specification.outage_generators
                generator = get_component(PowerSystems.Generator, sys, generator_name)
                add_supplemental_attribute!(sys, generator, outage)
            end
            # The same attribute links failed equipment to its responding service.
            for (reserve_type, reserve_name) in specification.responding_reserves
                reserve = get_component(reserve_type, sys, reserve_name)
                add_supplemental_attribute!(sys, reserve, outage)
            end
        end
    end
    return
end

# 1. Load forecast-backed data and assign regional membership explicitly.
sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)
area_to_subsystem = Dict("Area1" => "a", "Area2" => "b")
assign_example_subsystems!(sys, area_to_subsystem)

# 2. Isolate the fixture's contingency behavior, not realistic ramp-limited operation.
for generator in get_components(ThermalStandard, sys)
    set_ramp_limits!(generator, nothing)
end
for generator_name in ("Sundance_1", "Sundance_2")
    generator = get_component(ThermalStandard, sys, generator_name)
    set_must_run!(generator, true)
    set_active_power_limits!(generator, (min=1.0, max=2.0))
end

# 3. Declare modeled branch types before choosing their monitoring coverage.
template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, Line, StaticBranch)
set_device_model!(template, MonitoredLine, StaticBranch)

# 4. Specify and attach outages before DecisionModel finalizes their metadata.
outage_specifications = make_outage_specifications(sys)
add_outages_to_systems!([sys], outage_specifications)
@assert length(outage_specifications[1].monitored_components) == 7
@assert length(outage_specifications[2].monitored_components) == 6

# 5. Assign each responding service and register its security-constrained formulation.
for (subsystem, reserve_name) in (("a", "Reserve1_1"), ("b", "Reserve1_2"))
    reserve = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
    add_component_to_subsystem!(sys, subsystem, reserve)
    set_service_model!(
        template,
        ServiceModel(
            VariableReserve{ReserveUp},
            SecurityConstrainedRampReserve,
            reserve_name,
        ),
        subsystem,
    )
end

# 6. Build and solve the hourly dispatch; this is not a unit-commitment formulation.
problem = DecisionModel(
    MultiRegionProblem,
    template,
    sys;
    name="RegionalSecurityConstrainedDispatch",
    horizon=Hour(24),
    interval=Hour(1),
    resolution=Hour(1),
    optimizer=optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false),
)
@assert build!(problem; output_dir=mktempdir()) == PowerSimulations.ModelBuildStatus.BUILT
@assert solve!(problem) == PowerSimulations.RunStatus.SUCCESSFULLY_FINALIZED
results = OptimizationProblemResults(problem)

# 7. Check exported sparse flows and reserve conservation, not merely solve success.
for specification in outage_specifications
    reserve_type, reserve_name = only(specification.responding_reserves)
    reserve = get_component(reserve_type, sys, reserve_name)
    outage = only(get_supplemental_attributes(GeometricDistributionForcedOutage, reserve))
    flow_key = PowerSimulations.ExpressionKey{
        PostContingencyBranchFlow,
        VariableReserve{ReserveUp},
    }(
        reserve_name,
    )
    deployment_key = PowerSimulations.VariableKey{
        PostContingencyActivePowerReserveDeploymentVariable,
        VariableReserve{ReserveUp},
    }(
        reserve_name,
    )
    flows = get_expression_values(results)[flow_key]
    deployment = get_variable_values(results)[deployment_key]
    # Raw standalone tables encode outage UUID and branch in one name; values are p.u.
    outage_id = string(IS.get_uuid(outage))
    expected_names =
        Set(outage_id * "__" * name for name in specification.monitored_components)
    @assert Set(flows.name) == expected_names
    @assert Set(flows.time_index) == Set(1:24)
    @assert size(flows, 1) == 24 * length(expected_names)
    @assert all(isfinite, flows.value)
    for time_index in 1:24
        @assert count(==(time_index), flows.time_index) == length(expected_names)
        @assert isapprox(
            sum(deployment.value[deployment.time_index .== time_index]),
            1.0;
            atol=1e-6,
        )
    end
end
println(
    "Checked two generator outages, 13 monitored branch/outage pairs, and 24 hourly results.",
)
