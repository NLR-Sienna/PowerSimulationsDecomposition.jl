# Split-area modeling

The package decomposes **model construction and execution**, not System data
ownership. One System provides topology and forecasts, named subsystems select
regional components, and a `MultiProblemTemplate` produces regional PSI models.

## Regional decisions and network context

`SplitAreaPTDFPowerModel` uses area-level balances for the areas selected by a
regional network model. Local static-injection decisions contribute to both
their area balance and nodal power-balance expressions. Network PTDF expressions
retain the full bus context needed for line-flow calculations.

`StateEstimationInjections` supplies other subsystems' bus injections as
parameters in nodal expressions. These are not extra local generation decisions
and do not create an iterative exchange between regional solves.
Optional `AreaInterchange` decisions enter the from-area balance with coefficient
`-1` and the to-area balance with coefficient `+1`.

The [formulation library](../formulation_library/network.md) gives the equations
and baseline-flow correction. `StaticBranchUnboundedStateEstimation` is the
special monitored-line formulation; it is not an estimator that infers state
from noisy measurements.

## Construction and execution

```mermaid
flowchart TD
    T["MultiProblemTemplate: base and regional templates"]
    D["DecisionModel of MultiRegionProblem"]
    C["MultiOptimizationContainer: regional PSI containers"]
    N["Instantiate networks and build devices and services"]
    B["Build bus maps and joint result axes"]
    U["Update regional parameters from simulation state"]
    S["Sequential regional solves"]
    R["Copy dense values to joint stores"]
    P["PSI result storage and state updates"]
    F["Return regional failure status"]
    T -->|constructor deep-copies and finalizes| D
    D -->|owns through ModelInternal| C
    C -->|build calls| N
    N --> B
    B --> U
    U --> S
    S -->|all regional solves succeed| R
    S -->|a regional solve fails| F
    R --> P
```

Arrows describe construction calls and execution/data flow; they do not imply a
central optimization solve. A standalone solve does not require the
simulation-state update step. In a simulation, PSI repeats the update/solve/
storage portion according to the sequence and intervals.

The sequential implementation solves every regional container once per model
execution and returns early on failure. It does not update a later region from
an earlier region's freshly solved values inside that loop. Region iteration
follows dictionary iteration, not the sorted template-key accessor's order.
There is no residual criterion, iteration count, or convergence proof in this
path.

## Assumptions and limitations

  - Membership and boundary ownership are study inputs; the package does not
    optimize or automatically choose them.
  - Modeled static injections and their buses must be co-assigned. Modeled
    two-terminal HVDC terminal buses must be in the same subsystem.
  - Initialization changes the input System's unit setting to `SYSTEM_BASE`.
    Internal injections and flows are system-base per-unit quantities; preserve
    the System base and original branch direction when interpreting them.
  - A single time-series resolution is required by the multi-container constructor.
    Specifying `resolution` does not bypass that constructor restriction.
  - The [result aggregation limits](../how_to/results.md) matter for shared
    components and sparse outputs.
  - MPI (Message Passing Interface) execution is incomplete; no sequential/MPI
    equivalence is established.

These contracts are implemented by `multiproblem_template.jl`,
`multi_optimization_container.jl`, `problems/multi_region_problem.jl`,
`algorithms/sequential_algorithm.jl`, and `models/network_models.jl`.
