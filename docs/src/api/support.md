# Supported behavior and limitations

This table records source/test evidence, not a claim that every permitted
combination of upstream formulations has been validated.

**MPI** stands for **Message Passing Interface**, a standard for communication
between processes in parallel programs. `MPI.jl` provides the Julia interface.
This package includes MPI-related scaffolding, but its MPI execution path is
incomplete and is not selected by the public model constructor.

| Behavior                               | Evidence                                | Boundary                                                                                       |
|:-------------------------------------- |:--------------------------------------- |:---------------------------------------------------------------------------------------------- |
| Explicit AC branch membership          | `test_component_assignment.jl`          | Fixture uses from-bus assignment; no automatic ownership policy                                |
| Static injector/bus consistency        | `test_hvdc.jl`, sequential build checks | Checks available modeled injectors, not full partition coverage                                |
| Two-terminal HVDC membership           | `test_hvdc.jl`                          | Modeled endpoints must be in the same assigned subsystem                                       |
| Regional reserve construction          | `test_reserves.jl`                      | `RangeReserve` template propagation and regional constraint counts                             |
| Horizontal state passing               | `test_horizontal_passing.jl`            | Hourly prior-execution injection comparison; selected branch comparisons with/without emulator |
| Vertical state passing                 | `test_vertical_passing.jl`              | Same-window injection comparison and selected branch comparison                                |
| Hydro budget / one-dimensional results | `test_hydro.jl`                         | HydroPowerSimulations budget formulation in the RTS fixture                                    |
| Reserve deliverability                 | `test_reserve_deliverability.jl`, `test_component_assignment.jl` | Active generator-outage metadata, 10-bus reference/split monitoring, RTS selected-flow export and reserve conservation |
| MPI                                    | `algorithms/mpi_parallel_algorithm.jl`  | **Incomplete**; unresolved variables and missing execution/aggregation implementation          |

## Algorithms and results

  - The public model constructor selects `SequentialAlgorithm`. No public
    algorithm-selection keyword is implemented.
  - Regional solves run once each per execution; there is no convergence loop.
    They do not imply global-optimality or central/decomposed equivalence.
  - Dictionary iteration does not prescribe a stable coordination order.
  - Sparse result stores preserve actual regional tuple keys and evaluated
    values, without inventing outage/monitor combinations. Mixed dense/sparse
    representations for one key are rejected. Overlapping entries can still
    overwrite regional results; no regional axis is added to tables.
  - Parameter aggregation supports at most two dimensions. Joint-axis methods
    assume compatible time axes; this is not arbitrary tensor concatenation.
  - Regional optimizer/objective statistics are not a certified aggregate central
    optimization result.
  - Standalone `OptimizationProblemResults` can list names whose string-key
    metadata lookup is not populated. Use typed readers such as
    `read_variable(results, ActivePowerVariable, ThermalStandard; ...)`.

## Time, units, and integration hooks

  - The multi-container requires a single time-series resolution. Models require
    forecast data, not just a topology-only System.
  - Parameter updates copy indexed values and include an explicit
    differing-resolution TODO; general resampling is unsupported.
  - Initialization sets System units to `SYSTEM_BASE`, a visible mutation of the
    input System's unit setting.
  - The package's `handle_initial_conditions!`, numerical-bound-check override,
    and optimization-model serialization hook are no-ops. Do not assume they
    provide all default PSI checks or initialization behavior.
  - Device/service feedforwards use different attachment paths; absent device
    models fail explicitly, while service matching depends on type and optional
    service metadata.

## Compatibility and validation environments

The dependency upgrade targets PSI 0.38.4, PNM 0.24.4, PSY 5.12.3, and
InfrastructureSystems 3.6.3, with compatible updates allowed by `Project.toml`.
These bounds describe the requested dependency baseline, not proof that every
extension works with it. Validate runtime compatibility with the test suite.
The docs environment additionally declares its solver/fixture prerequisites.

Device and branch lookup delegates to the upstream template interface, and
regional pruning removes models by their stored dictionary keys. Importing
PowerSystems components into `Main` is not required. Component-assignment
regressions run in a fresh process with imports confined to a module, matching
the isolation used by Documenter's executable tutorial.

The repository declares test prerequisites in `test/Project.toml`; `Pkg.test()`
uses that environment together with the package under test. It includes hydro,
storage, solver, fixture, and Aqua dependencies. A missing import or resolver
failure is an environment blocker, not a failed physical-model assertion.

See [workflow and validation](../developer/workflow.md) for selectors and
transparent reporting of environment blockers.

Security-constrained reserve examples use `ReserveUp` and explicit eligible
monitoring sets. Empty monitoring is not all-component monitoring. See
[configuration](../how_to/security_constrained_reserves.md) and
[formulation-specific boundaries](../formulation_library/security_constrained.md).
