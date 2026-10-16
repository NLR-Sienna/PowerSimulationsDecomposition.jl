@testset "Test branches are assigned to subsystems correctly" begin
    sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)

    area_subsystem_map = Dict("Area1" => "a", "Area2" => "b")
    make_subsystems!(sys, area_subsystem_map)
    # From bus determines subsystem of ACBranch
    a_buses = get_components(ACBus, sys; subsystem_name="a")
    b_buses = get_components(ACBus, sys; subsystem_name="b")
    for b in get_components(ACTransmission, sys)
        from_bus = get_from(get_arc(b))
        if from_bus ∈ a_buses
            add_component_to_subsystem!(sys, "a", b)
        elseif from_bus ∈ b_buses
            add_component_to_subsystem!(sys, "b", b)
        end
    end
    template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, DeviceModel(MonitoredLine, StaticBranch))
    set_device_model!(template, DeviceModel(Line, StaticBranch))

    problem = DecisionModel(
        MultiRegionProblem,
        template,
        sys;
        horizon=Hour(24),
        interval=Hour(1),
        resolution=Hour(1),
        name="UC_Subsystem",
        optimizer=HiGHS_optimizer_small_gap,
    )

    build_out = build!(problem; output_dir=mktempdir())

    @test size(
        problem.internal.container.subproblems["a"].constraints[PSI.ConstraintKey{
            FlowRateConstraint,
            Line,
        }(
            "lb",
        )],
    )[1] == 6
    @test size(
        problem.internal.container.subproblems["b"].constraints[PSI.ConstraintKey{
            FlowRateConstraint,
            Line,
        }(
            "lb",
        )],
    )[1] == 6
    @test size(
        problem.internal.container.subproblems["a"].constraints[PSI.ConstraintKey{
            FlowRateConstraint,
            MonitoredLine,
        }(
            "lb",
        )],
    )[1] == 1
    @test !haskey(
        problem.internal.container.subproblems["b"].constraints,
        PSI.ConstraintKey{FlowRateConstraint, MonitoredLine}("lb"),
    )
end

@testset "Test component assignment without imports in Main" begin
    # The harness imports PowerSystems into Main, so module isolation needs a fresh process.
    test_environment = dirname(Base.active_project())
    test_file = joinpath(@__DIR__, "test_utils", "module_isolated_templates.jl")
    command = `$(Base.julia_cmd()) --startup-file=no --project=$test_environment $test_file`
    @test success(pipeline(command; stdout=stdout, stderr=stderr))
end

@testset "Regional security-constrained reserve outage metadata" begin
    sys = build_system(PSISystems, "two_area_pjm_DA"; add_reserves=true)
    area_subsystem_map = Dict("Area1" => "a", "Area2" => "b")
    make_subsystems!(sys, area_subsystem_map)
    for branch in get_components(ACTransmission, sys)
        area_name = get_name(get_area(get_from(get_arc(branch))))
        add_component_to_subsystem!(sys, area_subsystem_map[area_name], branch)
    end

    template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, Line, StaticBranch)
    set_device_model!(template, MonitoredLine, StaticBranch)
    outages = Dict{String, GeometricDistributionForcedOutage}()
    for (subsystem, suffix) in [("a", "1"), ("b", "2")]
        reserve_name = "Reserve1_" * suffix
        reserve = get_component(VariableReserve{ReserveUp}, sys, reserve_name)
        add_component_to_subsystem!(sys, subsystem, reserve)
        outage = GeometricDistributionForcedOutage(;
            mean_time_to_recovery=10.0,
            outage_transition_probability=1.0,
            monitored_components=[get_component(Line, sys, "1_" * suffix)],
        )
        generator = get_component(ThermalStandard, sys, "Sundance_" * suffix)
        add_supplemental_attribute!(sys, generator, outage)
        add_supplemental_attribute!(sys, reserve, outage)
        outages[subsystem] = outage
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

    problem = DecisionModel(
        MultiRegionProblem,
        template,
        sys;
        horizon=Hour(24),
        interval=Hour(1),
        resolution=Hour(1),
        optimizer=HiGHS_optimizer_small_gap,
    )
    for (subsystem, suffix) in [("a", "1"), ("b", "2")]
        sub_template =
            PowerSimulationsDecomposition.get_sub_templates(PSI.get_template(problem))[subsystem]
        service_model =
            PSI.get_model(sub_template, VariableReserve{ReserveUp}, "Reserve1_" * suffix)
        @test Set(keys(service_model.outages)) == Set([IS.get_uuid(outages[subsystem])])
    end
    @test build!(problem; output_dir=mktempdir()) == PSI.ModelBuildStatus.BUILT
    for (subsystem, suffix) in [("a", "1"), ("b", "2")]
        container = PSI.get_optimization_container(problem).subproblems[subsystem]
        deployment_key = PSI.VariableKey{
            PostContingencyActivePowerReserveDeploymentVariable,
            VariableReserve{ReserveUp},
        }(
            "Reserve1_" * suffix,
        )
        @test haskey(PSI.get_variables(container), deployment_key)
    end
end
