# Public API

```@meta
CurrentModule = PowerSimulationsDecomposition
```

These are the five bindings exported by this package. Constructors and
formulations use PowerSystems data and PowerSimulations modeling interfaces;
PSI's setters, `DecisionModel`, `build!`, `solve!`, and result readers are not
re-exported here.

```@docs
MultiProblemTemplate
MultiRegionProblem
SplitAreaPTDFPowerModel
StaticBranchUnboundedStateEstimation
NetworkFlowConstraintStateEstimation
```

For executable composition, see the [tutorial](../tutorials/intro_page.md).
For equations, see the [formulation library](../formulation_library/network.md).
Qualified internals are documented [separately](internal.md).
