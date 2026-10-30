# Assign subsystems

Named subsystems are component memberships in **one** PowerSystems `System`.
Creating a `MultiProblemTemplate` does not create, infer, or validate a complete
partition of that System.

## Create memberships explicitly

The tutorial's policy is area-based; this is an example, not a package default:

```julia
using PowerSystems
add_subsystem!(sys, "a")
area = get_component(Area, sys, "Area1")
add_component_to_subsystem!(sys, "a", area)

for bus in get_components(ACBus, sys)
    if get_name(get_area(bus)) == "Area1"
        add_component_to_subsystem!(sys, "a", bus)
    end
end
for device in get_components(StaticInjection, sys)
    if get_name(get_area(get_bus(device))) == "Area1"
        add_component_to_subsystem!(sys, "a", device)
    end
end
```

Repeat for the other region, or use the complete
[tutorial](../tutorials/intro_page.md). Assigning an area does not automatically
assign its buses, generators, loads, branches, or reserve services. Inspect
`get_subsystems(sys)` and
`collect(get_components(ACBus, sys; subsystem_name="a"))` to verify membership.

## Choose branch ownership

Assign each modeled branch explicitly:

```julia
for branch in get_components(ACTransmission, sys)
    from_bus = get_from(get_arc(branch))
    if get_name(get_area(from_bus)) == "Area1"
        add_component_to_subsystem!(sys, "a", branch)
    end
end
```

This is the **from-bus policy** demonstrated in
`test/test_component_assignment.jl`. The multistage RTS fixture instead assigns
selected lines using their **to-bus area**. Neither policy is automatic or
universally correct. Boundary ownership must reflect the study's intended model.
Assignment does not reverse the branch arc or redefine its flow sign.

PTDF network data can include buses outside a region even though the region
owns only selected modeled branches and injections. Do not interpret a regional
container as a disconnected, copied network.

### HVDC and static injectors

Before constructing regional optimization problems, `build_main_problem!` checks
available, modeled components:

  - A static injector assigned to a subsystem must have its attached bus in that
    subsystem, or construction raises `ConflictingInputsError`.
  - If a supported two-terminal HVDC type is modeled, both terminal buses must
    belong to the HVDC component's subsystem. A cross-subsystem terminal assignment
    fails the build.
  - With `SplitAreaPTDFPowerModel`, each modeled HVDC terminal bus's area must also
    be assigned to that subsystem. Moving a bus's subsystem membership does not
    change its area or assign that area to the subsystem. Missing terminal-area
    membership raises `ConflictingInputsError` before regional variables are built.
    For example, an HVDC connecting areas `1` and `3` can be internal to subsystem
    `a` when both areas and their terminal buses are assigned to `a`.

Omitting the HVDC model bypasses these HVDC modeling checks; it does **not** model
the interregional HVDC transfer.

#### Allowed and rejected HVDC assignments

An area is the component referenced by `get_area(bus)`. A subsystem is a named
collection of explicitly assigned components. They are different concepts: a
subsystem can contain several areas, and assigning a bus to a subsystem does not
change its area.

For an available HVDC assigned to `a` and modeled with
`SplitAreaPTDFPowerModel`, the following configurations illustrate the checks:

| Terminal areas          | Terminal bus memberships     | Area memberships                                  | Outcome                         |
|:----------------------- |:---------------------------- |:------------------------------------------------- |:------------------------------- |
| Both in area `1`        | Both in `a`                  | Area `1` in `a`                                   | Allowed                         |
| Areas `1` and `3`       | Both in `a`                  | Both areas in `a`                                 | Allowed                         |
| Areas `1` and `3`       | Both in `a`                  | Area `3` absent from `a`, even if assigned to `b` | Rejected: missing terminal area |
| Same or different areas | One terminal absent from `a` | Any                                               | Rejected: missing terminal bus  |

Thus, **cross-area HVDC is allowed inside a subsystem; cross-subsystem HVDC is
not supported by this regional construction**. These checks do not require the
two terminals to share an area, or prove complete coverage, disjoint ownership,
or conservation for an arbitrary user partition.

The two positive cases in `test/test_hvdc.jl` use fresh
`modified_RTS_GMLC_DA_sys` fixtures:

  - **Same-area case:** change the ending bus's area to the starting bus's area
    before assigning subsystems. Keep areas `1` in `a` and `2` and `3` in `b`.
    Assign both terminal buses and the HVDC to `a`.
  - **Different-area case:** leave both buses' areas unchanged. Assign areas `1`
    and `3`, their terminal buses, and the HVDC to `a`; keep area `2` in `b`.

The first case changes the test System's area definition, not the HVDC arc or
flow direction:

```julia
hvdc = get_component(TwoTerminalGenericHVDCLine, sys, "DC1")
from_bus = get_from(get_arc(hvdc))
to_bus = get_to(get_arc(hvdc))
set_area!(to_bus, get_area(from_bus))
```

This snippet assumes a fresh RTS fixture and does not assign subsystem
memberships. Afterward, use the public membership APIs above to assign areas,
buses, attached modeled injections, and the HVDC consistently. Do not change
real-system area definitions merely to bypass validation; that changes which
area balance receives the bus's injections.

The regressions configure `HVDCTwoTerminalLossless` for
`TwoTerminalGenericHVDCLine`. They check `-flow` at the starting bus, `+flow` at
the ending bus, the corresponding area contributions, and cancellation in the
area balance when both terminals share an area. They do not establish support
for every lossy HVDC formulation or guarantee a feasible solve for arbitrary
limits and injections. See [HVDC balance behavior](../explanation/decomposition.md#HVDC-area-balances-and-dependency-compatibility)
for the upstream change behind these checks.

## Populate the template

```julia
using PowerSimulations
using PowerSimulationsDecomposition

template = MultiProblemTemplate(NetworkModel(SplitAreaPTDFPowerModel), ["a", "b"])
set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, Line, StaticBranch)
```

The constructor deep-copies the base template into regional templates.
The PSI setters apply model configuration across those templates and set
subsystem names. Prefer configuring the network in the constructor, as in the
tests; mutating template fields directly is an internal operation.

DecisionModel construction deep-copies and finalizes the template. Finalization
removes empty device/branch models in each subsystem with warnings, populates
service contributors, and records modeled AC branch types. At network
instantiation, branch filters are intersected with subsystem membership.
An empty regional model is not evidence that all intended devices were assigned.

## Add services and interchanges deliberately

For regional reserve services, preserve the PowerSystems service-to-contributing-
device associations, assign the service to its subsystem, and configure a
compatible PSI service formulation:

```julia
reserve = get_component(VariableReserve{ReserveUp}, sys, "Spin_Up_R1")
add_component_to_subsystem!(sys, "a", reserve)
set_service_model!(
    template,
    ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "Spin_Up_R1"),
    "a",
)
```

This overload also adds the service to the base template. The service name is
fixture-specific; inspect your own System. `RangeReserve` construction tests
do not by themselves establish reserve deliverability. Separate active tests
cover `SecurityConstrainedRampReserve` with explicit outage monitoring in the
10-bus and RTS fixtures.

For security-constrained services, attach the outage to both its failed
generator and responding service, and choose monitors from branches actually
modeled in the consuming region. Include eligible boundary branches according
to the study's ownership policy; do not copy all System branches to every region.
Make these choices before constructing the `DecisionModel`, which finalizes
regional outage metadata. Follow
[Configure security-constrained reserves](security_constrained_reserves.md) for
typed outage specifications, helper functions, and all-eligible/subset recipes.

The multistage test fixture explicitly creates `AreaInterchange` components and
assigns each to both subsystems so that their area-balance expressions can use
the interchange. This intentional shared membership is not a general overlap
policy: aggregation can overwrite shared component axes. A vertical
`FixValueFeedforward` fixes interchange values to the producer's decisions.
See [state passing](../explanation/state_passing.md).

## Pre-build checklist

  - Subsystem names match the template keys.
  - Areas, buses, and modeled static injections have the intended membership.
  - Modeled HVDC endpoints satisfy the same-subsystem restriction; with
    `SplitAreaPTDFPowerModel`, both endpoint areas are also assigned there.
  - Modeled branches have explicit ownership and compatible filters.
  - Services and contributing devices retain their intended associations.
  - Forecast horizon, interval, and resolution cover every execution.
  - Shared memberships have an explicit study rationale; result aggregation is
    not assumed to resolve conflicts.

Do not use `make_subsystems!`, `add_interchanges!`, or `get_jump_models` as
package APIs: those names are defined only by the test utilities.
