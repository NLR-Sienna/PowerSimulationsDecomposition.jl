module ModuleIsolatedTemplates

using Dates
using HiGHS
using JuMP
using InfrastructureSystems
using PowerSimulations
using PowerSimulationsDecomposition
using PowerSystemCaseBuilder
using PowerSystems
using Test

const PSI = PowerSimulations
const PSD = PowerSimulationsDecomposition
const IS = InfrastructureSystems

include(joinpath(@__DIR__, "system_modifications.jl"))

@testset "Test templates without imports in Main" begin
    @test !isdefined(Main, :PowerSystems)
    @test !isdefined(Main, :MonitoredLine)

    @testset "Test base and regional device and branch lookup" begin
        template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
        set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
        set_device_model!(template, MonitoredLine, StaticBranch)

        for component_type in (ThermalStandard, MonitoredLine)
            model = PSI.get_model(template, component_type)
            @test model isa DeviceModel
            @test model === PSI.get_model(template.base_template, component_type)
            for subsystem in ("a", "b")
                regional_model = PSI.get_model(template, component_type, subsystem)
                @test regional_model isa DeviceModel
                @test regional_model ===
                      PSI.get_model(template.sub_templates[subsystem], component_type)
            end
        end
        @test PSI.get_model(template, PowerLoad) === nothing
        @test PSI.get_model(template, PowerLoad, "a") === nothing
        @test_throws KeyError PSI.get_model(template, ThermalStandard, "missing")
    end

    @testset "Test unused regional device and branch models are removed" begin
        sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)
        area_subsystem_map = Dict("Area1" => "a", "Area2" => "b")
        make_subsystems!(sys, area_subsystem_map)
        for branch in get_components(ACTransmission, sys)
            from_bus = get_from(get_arc(branch))
            subsystem = area_subsystem_map[get_name(get_area(from_bus))]
            add_component_to_subsystem!(sys, subsystem, branch)
        end
        for renewable in collect(get_components(RenewableDispatch, sys))
            remove_component!(sys, renewable)
        end
        template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
        set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
        set_device_model!(template, PowerLoad, StaticPowerLoad)
        set_device_model!(template, MonitoredLine, StaticBranch)
        set_device_model!(template, Line, StaticBranch)
        @test isempty(get_components(RenewableDispatch, sys))
        @test isempty(get_components(RenewableNonDispatch, sys))
        set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
        set_device_model!(template, RenewableNonDispatch, FixedOutput)

        problem = DecisionModel(
            MultiRegionProblem,
            template,
            sys;
            horizon=Hour(24),
            interval=Hour(1),
            resolution=Hour(1),
            optimizer=optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false),
        )
        finalized_template = PSI.get_template(problem)
        @test PSI.get_model(finalized_template, MonitoredLine, "a") isa DeviceModel
        @test PSI.get_model(finalized_template, MonitoredLine, "b") === nothing
        @test PSI.get_model(template, MonitoredLine, "b") isa DeviceModel
        for subsystem in ("a", "b")
            @test PSI.get_model(finalized_template, RenewableDispatch, subsystem) ===
                  nothing
            @test PSI.get_model(finalized_template, RenewableNonDispatch, subsystem) ===
                  nothing
            @test PSI.get_model(template, RenewableDispatch, subsystem) isa DeviceModel
        end
        @test build!(problem; output_dir=mktempdir()) == PSI.ModelBuildStatus.BUILT
    end

    @testset "Test modeled injector must share its bus subsystem" begin
        sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)
        make_subsystems!(sys, Dict("Area1" => "a", "Area2" => "b"))
        load = first(get_components(PowerLoad, sys; subsystem_name="a"))
        bus = get_bus(load)
        remove_component_from_subsystem!(sys, "a", bus)
        add_component_to_subsystem!(sys, "b", bus)
        template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
        set_device_model!(template, PowerLoad, StaticPowerLoad)
        problem = DecisionModel(
            MultiRegionProblem,
            template,
            sys;
            horizon=Hour(24),
            interval=Hour(1),
            resolution=Hour(1),
        )
        @test_throws IS.ConflictingInputsError PSD.build_main_problem!(
            PSI.get_optimization_container(problem),
            PSI.get_template(problem),
            sys,
        )

        unmodeled_template =
            MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
        @test isnothing(
            PSD.build_main_problem!(
                PSI.get_optimization_container(problem),
                unmodeled_template,
                sys,
            ),
        )
    end
end

end
