# Network and state-estimation formulations

This compact library documents mathematical behavior **owned by this package**.
It complements the [modeling explanation](../explanation/decomposition.md) and
[API reference](../api/public.md); it does not reproduce PSI's thermal, load,
reserve, or hydro libraries.

## Notation and units

The symbols below describe the equations on this page. Internal active-power
quantities are system-base per-unit (p.u.) after initialization; the System's
base apparent power is given by `PowerSystems.get_base_power(sys)` in MVA.

| Symbol                         | Definition                                                                   | Units                                           |
|:------------------------------ |:---------------------------------------------------------------------------- |:----------------------------------------------- |
| ``r``                          | Region/subsystem identifier                                                  | Identifier; no physical units                   |
| ``B_r``                        | Buses explicitly assigned to region ``r``                                    | Set of bus identifiers                          |
| ``A_r``                        | Areas explicitly assigned to region ``r``                                    | Set of area identifiers                         |
| ``b``, ``a``                   | Mapped bus index and area index                                              | Indices; no physical units                      |
| ``\ell``                       | Branch index in the PTDF network                                             | Index; no physical units                        |
| ``d``, ``i``                   | Modeled static-injection device index and area-interchange index             | Indices; no physical units                      |
| ``t``                          | Discrete model time index, not elapsed time                                  | Index; physical spacing is the model resolution |
| ``H_{\ell b}``                 | Power transfer distribution factor from bus ``b`` to branch ``\ell``         | Dimensionless                                   |
| ``\hat p_{bt}``                | Baseline state-estimation injection at bus ``b`` and time ``t``              | System-base p.u. active power                   |
| ``\hat f_{\ell t}``            | Baseline state-estimation flow on branch ``\ell`` at time ``t``              | System-base p.u. active power                   |
| ``e^{(r)}_{bt}``               | Regional nodal active-power-balance expression used for PTDF flows           | System-base p.u. active power                   |
| ``e^{\mathrm{local}}_{bt}``    | Nodal expression from local modeled injections and network contributions     | System-base p.u. active power                   |
| ``e^{\mathrm{network}}_{bt}``  | Existing nodal network contributions before adding the nonregional baseline  | System-base p.u. active power                   |
| ``x_{dt}``                     | Active-power decision for device ``d`` in the schematic area balance         | System-base p.u. active power                   |
| ``m_d``                        | PSI formulation-specific sign/scaling multiplier for the device contribution | Dimensionless                                   |
| ``q_{it}``                     | Modeled active-power interchange from its from-area to its to-area           | System-base p.u. active power                   |
| ``s^{+}_{at}``, ``s^{-}_{at}`` | Nonnegative upward/downward area-balance slacks                              | System-base p.u. active power                   |
| ``f^{(r)}_{\ell t}``           | Reconstructed regional branch-flow expression                                | System-base p.u. active power                   |

PTDF coefficients are dimensionless. A positive area-interchange flow follows
its from-area to to-area direction. Assignment does not change branch signs.
These units describe internal expressions, not a blanket conversion rule for
PowerSystems getters or result tables; see [result units](../how_to/results.md).

Network reductions use PNM's mapped bus numbers. Bus-number strings index
state-estimation parameters; physical component names index branch parameters.
Do not substitute arbitrary column positions for these identities.

## SplitAreaPTDFPowerModel

`models/network_models.jl` extends PSI network construction and expression
assembly:

  - Local modeled static injections contribute, with PSI's formulation-specific
    variable multipliers, to both area and nodal balance expressions.
  - Nonregional, non-isolated available buses receive baseline injections in
    their nodal expressions:

```math
e^{(r)}_{bt} =
\begin{cases}
e^{\mathrm{local}}_{bt}, & b \in B_r,\\
e^{\mathrm{network}}_{bt} + \hat p_{bt}, & b \notin B_r.
\end{cases}
```

Here ``e^{\mathrm{network}}`` denotes any existing network contributions; the
implementation adds the baseline term, rather than replacing the expression.
Each selected area has its assembled active-power balance constrained to zero:

```math
\sum_{d \in a} m_d x_{dt}
- \sum_{i:\,\mathrm{from}(i)=a} q_{it}
+ \sum_{i:\,\mathrm{to}(i)=a} q_{it}
+ s^{+}_{at} - s^{-}_{at} = 0,
\qquad a \in A_r.
```

``m_d`` represents the applicable PSI injection/load multiplier and other
modeled balance contributions are included by their owning formulations.
Interchange terms exist only if `AreaInterchange` is modeled.
Slacks exist only when `use_slacks=true`; they are nonnegative and carry PSI's
`BALANCE_SLACK_COST` penalty. The equation is a guide to expression assembly,
not an additional independent nodal-balance constraint at every external bus.

The code selects the available regional areas for balance constraints, uses
`AreaPTDFPowerModel` to initialize system expressions, and maps device buses
through the network reduction. Nonregional injections provide network context;
they are not reoptimized locally.

## StaticBranchUnboundedStateEstimation

This exported branch formulation has concrete construction methods for
`MonitoredLine` with a PSI `AbstractPTDFModel`, but also requires the
`StateEstimationInjections` store created by `SplitAreaPTDFPowerModel`.
Ordinary PSI PTDF network models do not create that store automatically.
The branch formulation adds a `StateEstimationFlows` parameter and a
`PTDFBranchFlow` expression. Source: `models/branch_models.jl`.

For each modeled monitored line, the reconstructed expression is:

```math
f^{(r)}_{\ell t}
= \sum_b H_{\ell b} e^{(r)}_{bt}
+ \hat f_{\ell t}
- \sum_b H_{\ell b} \hat p_{bt}.
```

The baseline-flow multiplier is initialized to one. The last sum uses the sorted
available non-isolated bus numbers in the implementation, so PTDF/bus ordering
must remain consistent. This is a baseline plus injection-change calculation;
it is not statistical state estimation.

`NetworkFlowConstraintStateEstimation` registers the corresponding equality.
The construction passes the registered `PTDFBranchFlow` expression through the
flow builder, which mutates that expression store, then forms the equality
against the registered expression. Do not infer a new independent bounded flow
variable from the constraint's name. In particular, this unbounded formulation
does **not** add thermal/rating inequalities; feedforward constraints and dual
registration are handled separately by PSI hooks.

Use PSI's `StaticBranch` or another compatible upstream formulation when actual
rating enforcement is required, and verify the resulting constraint set. The
active tests compare flow results, not a general rating-deliverability theorem.

## Baseline parameters

| Qualified internal type                                   | Component       | Source expression    | Initialization                                           |
|:--------------------------------------------------------- |:--------------- |:-------------------- |:-------------------------------------------------------- |
| `PowerSimulationsDecomposition.StateEstimationInjections` | `ACBus`         | `ActivePowerBalance` | All PTDF bus-axis entries, zero values, unit multipliers |
| `PowerSimulationsDecomposition.StateEstimationFlows`      | `MonitoredLine` | `PTDFBranchFlow`     | Modeled branch names, zero values, unit multipliers      |

Both derive from PSI's `VariableValueParameter`. Their source expression keys
have empty metadata. They update from system state, with warned decision-state
fallback under the conditions described in [State passing](../explanation/state_passing.md).
Finite-value checks do not implement interpolation, averaging, or a
differing-resolution contract.

## Upstream formulations and coverage

Thermal dispatch/commitment, `StaticPowerLoad`, ordinary branch limits,
`AreaInterchange`, and `RangeReserve` are PSI formulations, not new types
provided here. Hydro-budget behavior in the active hydro test is supplied by
HydroPowerSimulations. Consult the resolved dependency source and its
version-matched documentation; newer PSI documentation can describe unsupported
APIs.

  - [PowerSimulations 0.34.2 source](https://github.com/Sienna-Platform/PowerSimulations.jl/tree/v0.34.2/src)
  - [HydroPowerSimulations repository](https://github.com/Sienna-Platform/HydroPowerSimulations.jl)
  - [Supported behavior and test evidence](../api/support.md)

There is no separate optimization-based partitioning formulation or completed
MPI (Message Passing Interface) algorithm implemented by this package.
