# Internal extensions

These bindings are **not exported** and are version-sensitive implementation
details. Qualify them with `PowerSimulationsDecomposition` when inspecting them.
Prefer the [public API](public.md) for user code.

```@docs
PowerSimulationsDecomposition.DecompositionAlgorithm
PowerSimulationsDecomposition.SequentialAlgorithm
PowerSimulationsDecomposition.MPIParallelAlgorithm
PowerSimulationsDecomposition.MultiOptimizationContainer
PowerSimulationsDecomposition.StateEstimationInjections
PowerSimulationsDecomposition.StateEstimationFlows
```

## Extension map

| Source                               | Internal binding or PSI extension                                           | Responsibility                                             |
|:------------------------------------ |:--------------------------------------------------------------------------- |:---------------------------------------------------------- |
| `multiproblem_template.jl`           | `get_sub_templates`, `get_sub_problem_keys`, `finalize_template!`           | Regional template access, sorted keys, finalization        |
| `multiproblem_template.jl`           | `PSI.set_device_model!`, `PSI.set_service_model!`, `PSI.set_network_model!` | Configure base/regional models and subsystem filters       |
| `multi_optimization_container.jl`    | `init_optimization_container!` and PSI accessors                            | Initialize regional containers, settings, axes, and stores |
| `problems/multi_region_problem.jl`   | `PSI.DecisionModel{MultiRegionProblem}`                                     | Construct the model with sequential dispatch               |
| `problems/multi_region_problem.jl`   | `PSI.build_impl!`, `PSI.build_model!`, `PSI.solve_impl!`                    | Integrate regional build and solve into PSI                |
| `problems/multi_region_problem.jl`   | `_map_containers`, `_make_parameter_container!`                             | Allocate joint dense axes and parameter stores             |
| `problems/multi_region_problem.jl`   | `PSI._add_feedforward_to_model`                                             | Attach device/service feedforwards to sub-templates        |
| `problems/multi_region_problem.jl`   | `PSI.update_parameters!`, `PSI.update_model!`, `PSI.update_system_state!`   | Simulation-state integration                               |
| `algorithms/sequential_algorithm.jl` | `build_impl!`, `solve_impl!`, `write_results_to_main_container`             | Build/solve each region and copy results                   |
| `models/network_models.jl`           | PSI network/expression/parameter methods                                    | Area balances, nodal baselines, parameter updates          |
| `models/branch_models.jl`            | PSI device/flow/constraint methods                                          | Baseline-corrected monitored-line flows                    |

The [developer lifecycle](../developer/architecture.md) explains call order and
owning packages. The aliases `PSI`, `PSY`, `PNM`, `IS`, `ISOPT`, `ISSIM`, `PM`, and
`MOI` are internal conveniences, not exported dependency APIs.

Test helpers such as `make_subsystems!`, `get_jump_models`, and
`run_rts_multi_stage_decomposition_simulation` are not package bindings.
