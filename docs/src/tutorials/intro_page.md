# Two-region dispatch

Build a small regional dispatch model, solve it, and verify the joined thermal
generation results. Follow [setup](../quick_start_guide.md) first. This example is
adapted from `test/test_component_assignment.jl`, not from an exported partitioning
helper.

## Scope and assumptions

The PowerSystemCaseBuilder `two_area_pjm_DA` fixture has two areas. This example
assigns areas, their buses, and static injections to subsystems `a` and `b`.
It assigns each AC transmission branch to the subsystem of its **from** bus,
matching the component-assignment test's example policy.

The model uses `ThermalBasicDispatch`, not unit commitment. Reserve data are
loaded with the fixture, as in the test, but no reserve service is modeled here.
There is no `AreaInterchange` model or inter-stage state producer in this tutorial:
state-estimation injections start at zero and each area's balance is enforced
locally. This is a runnable construction/aggregation example, **not** an
equivalent solution of a centrally coordinated market or an accuracy study.

## Execute the example

The complete script uses public PowerSystems/PowerSimulations APIs and the two
exported decomposition entry points. It does not include test utilities.
From the repository root:

```powershell
julia --project=docs docs\examples\decomposition.jl
```

The complete script below is read directly from
`docs/examples/decomposition.jl` during each documentation build, including its
comments. Editing the script updates this listing without editing this page.
The build also executes that same file and checks its assertions.

```@eval
using Markdown
Markdown.MD([
    Markdown.Code(
        "julia",
        read(joinpath(@__DIR__, "..", "..", "examples", "decomposition.jl"), String),
    ),
])
```

```@example decomposition
include(joinpath(@__DIR__, "..", "..", "examples", "decomposition.jl")) # hide
nothing # hide
```

## What the script does

 1. Load a forecast-backed fixture; create the two named subsystems.
 2. Explicitly add areas, buses, static injections, and AC branches to them.
 3. Construct `MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])`.
 4. Use PSI's `set_device_model!` methods to populate the base and regional templates.
 5. Construct `DecisionModel(MultiRegionProblem, template, sys; ...)` with a
    24-hour horizon, one-hour interval, and one-hour resolution.
 6. Assert `ModelBuildStatus.BUILT` and `RunStatus.SUCCESSFULLY_FINALIZED`.
 7. Read `ActivePowerVariable__ThermalStandard` in wide format and assert 24 rows,
    exactly the fixture's thermal-generator columns, finite values, and dispatch
    above `-1e-6` (numerical feasibility tolerance).

That final message is a success check, not a claim about central optimality or
regional convergence. Build/solve logs and results are written to a temporary
output directory selected by the script.

## Adapt it safely

Before changing membership, read [Assign subsystems](../how_to/subsystems.md).
For inter-stage forecasts and state-estimation flows, read
[State passing](../explanation/state_passing.md) and the
[formulation library](../formulation_library/network.md).
Use [Read results](../how_to/results.md) to discover keys instead of assuming
every formulation emits the same entries.
