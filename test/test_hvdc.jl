@testset "HVDC spans subsystems but is not modeled (build suceeds)" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    area_subsystem_map = Dict("1" => "a", "2" => "b", "3" => "b")
    make_subsystems!(sys, area_subsystem_map)
    hvdc = get_component(TwoTerminalGenericHVDCLine, sys, "DC1")
    PowerSystems.add_component_to_subsystem!(sys, "a", hvdc)
    template_uc2 = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
    problem = DecisionModel(
        MultiRegionProblem,
        template_uc2,
        sys;
        name="UC_Subsystem",
        optimizer=optimizer_with_attributes(HiGHS.Optimizer),
    )
    @test build!(problem; output_dir=mktempdir()) == PowerSimulations.ModelBuildStatus.BUILT
end

@testset "HVDC spans subsystems and is modeled (build fails)" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    area_subsystem_map = Dict("1" => "a", "2" => "b", "3" => "b")
    make_subsystems!(sys, area_subsystem_map)
    hvdc = get_component(TwoTerminalGenericHVDCLine, sys, "DC1")
    PowerSystems.add_component_to_subsystem!(sys, "a", hvdc)
    template_uc2 = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
    set_device_model!(template_uc2, TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless)
    problem = DecisionModel(
        MultiRegionProblem,
        template_uc2,
        sys;
        name="UC_Subsystem",
        optimizer=optimizer_with_attributes(HiGHS.Optimizer),
    )
    build_out = build!(problem; console_level=Logging.AboveMaxLevel, output_dir=mktempdir())
    @test build_out == PowerSimulations.ModelBuildStatus.FAILED
end

@testset "Modeled HVDC terminals and areas belong to the same subsystem" begin
    for same_area in (false, true)
        @testset "Terminal buses share an area: $same_area" begin
            sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
            hvdc = get_component(TwoTerminalGenericHVDCLine, sys, "DC1")
            from_bus = get_from(get_arc(hvdc))
            to_bus = get_to(get_arc(hvdc))
            if same_area
                set_area!(to_bus, get_area(from_bus))
            end
            area_subsystem_map =
                Dict("1" => "a", "2" => "b", "3" => (same_area ? "b" : "a"))
            make_subsystems!(sys, area_subsystem_map)
            add_component_to_subsystem!(sys, "a", hvdc)
            @test (get_name(get_area(from_bus)) == get_name(get_area(to_bus))) == same_area
            @test is_assigned_to_subsystem(
                sys,
                get_component(Area, sys, "3"),
                same_area ? "b" : "a",
            )
            for bus in (from_bus, to_bus)
                @test is_assigned_to_subsystem(sys, bus, "a")
                @test is_assigned_to_subsystem(sys, get_area(bus), "a")
            end
            template =
                MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
            set_device_model!(template, TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless)
            problem = DecisionModel(
                MultiRegionProblem,
                template,
                sys;
                name="UC_Subsystem",
                optimizer=optimizer_with_attributes(HiGHS.Optimizer),
            )
            @test build!(problem; output_dir=mktempdir()) == PSI.ModelBuildStatus.BUILT

            container = PowerSimulationsDecomposition.get_subproblem(
                PSI.get_optimization_container(problem),
                "a",
            )
            sub_template =
                PowerSimulationsDecomposition.get_sub_templates(PSI.get_template(problem))["a"]
            network_reduction =
                PSI.get_network_reduction(PSI.get_network_model(sub_template))
            from_number =
                PowerNetworkMatrices.get_mapped_bus_number(network_reduction, from_bus)
            to_number =
                PowerNetworkMatrices.get_mapped_bus_number(network_reduction, to_bus)
            from_area = get_name(get_area(from_bus))
            to_area = get_name(get_area(to_bus))
            flow = PSI.get_variable(
                container,
                FlowActivePowerVariable(),
                TwoTerminalGenericHVDCLine,
            )
            nodal_balance = PSI.get_expression(container, ActivePowerBalance(), ACBus)
            area_balance = PSI.get_expression(container, ActivePowerBalance(), Area)
            for t in axes(flow, 2)
                @test coefficient(nodal_balance[from_number, t], flow["DC1", t]) == -1.0
                @test coefficient(nodal_balance[to_number, t], flow["DC1", t]) == 1.0
                for area_name in axes(area_balance, 1)
                    expected =
                        (area_name == to_area ? 1.0 : 0.0) -
                        (area_name == from_area ? 1.0 : 0.0)
                    @test coefficient(area_balance[area_name, t], flow["DC1", t]) ==
                          expected
                end
            end
        end
    end
end

@testset "Modeled HVDC terminal area is absent from its subsystem (build fails)" begin
    for area_name in ("1", "3")
        @testset "Missing terminal area $area_name" begin
            sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
            make_subsystems!(sys, Dict("1" => "a", "2" => "b", "3" => "a"))
            hvdc = get_component(TwoTerminalGenericHVDCLine, sys, "DC1")
            add_component_to_subsystem!(sys, "a", hvdc)
            area = get_component(Area, sys, area_name)
            remove_component_from_subsystem!(sys, "a", area)
            add_component_to_subsystem!(sys, "b", area)
            template =
                MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
            set_device_model!(template, TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless)
            problem = DecisionModel(
                MultiRegionProblem,
                template,
                sys;
                name="UC_Subsystem",
                optimizer=optimizer_with_attributes(HiGHS.Optimizer),
            )
            container = PSI.get_optimization_container(problem)
            finalized_template = PSI.get_template(problem)
            @test_throws IS.ConflictingInputsError PowerSimulationsDecomposition.build_main_problem!(
                container,
                finalized_template,
                sys,
            )
            @test_throws Regex("HVDC DC1.*area $area_name.*subsystem a") PowerSimulationsDecomposition.build_main_problem!(
                container,
                finalized_template,
                sys,
            )
            @test build!(
                problem;
                console_level=Logging.AboveMaxLevel,
                output_dir=mktempdir(),
            ) == PSI.ModelBuildStatus.FAILED
            for subsystem in ("a", "b")
                subproblem =
                    PowerSimulationsDecomposition.get_subproblem(container, subsystem)
                @test num_variables(PSI.get_jump_model(subproblem)) == 0
            end

            non_area_template =
                MultiProblemTemplate(NetworkModel(PTDFPowerModel), ["a", "b"])
            set_device_model!(
                non_area_template,
                TwoTerminalGenericHVDCLine,
                HVDCTwoTerminalLossless,
            )
            empty!(container.subproblem_bus_map)
            @test isnothing(
                PowerSimulationsDecomposition.build_main_problem!(
                    container,
                    non_area_template,
                    sys,
                ),
            )
            @test Set(keys(container.subproblem_bus_map)) == Set(["a", "b"])
        end
    end
end

@testset "Modeled component belongs to different subsystem than attached bus (build fails)" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    area_subsystem_map = Dict("1" => "a", "2" => "b", "3" => "b")
    a_1 = get_component(Area, sys, "1")
    b_chifa = get_component(ACBus, sys, "Chifa")
    set_area!(b_chifa, a_1)
    make_subsystems!(sys, area_subsystem_map)
    PowerSystems.remove_component_from_subsystem!(sys, "a", b_chifa)
    PowerSystems.add_component_to_subsystem!(sys, "b", b_chifa)
    template_uc2 = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
    set_device_model!(template_uc2, PowerLoad, StaticPowerLoad)
    problem = DecisionModel(
        MultiRegionProblem,
        template_uc2,
        sys;
        name="UC_Subsystem",
        optimizer=optimizer_with_attributes(HiGHS.Optimizer),
    )
    build_out = build!(problem; console_level=Logging.AboveMaxLevel, output_dir=mktempdir())
    @test build_out == PowerSimulations.ModelBuildStatus.FAILED
end
