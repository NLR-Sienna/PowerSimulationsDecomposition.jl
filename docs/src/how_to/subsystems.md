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

`build_main_problem!` checks available, modeled components:

  - A static injector assigned to a subsystem must have its attached bus in that
    subsystem, or construction raises `ConflictingInputsError`.
  - If a supported two-terminal HVDC type is modeled, both terminal buses must
    belong to the HVDC component's subsystem. A cross-subsystem terminal assignment
    fails the build. Omitting the HVDC model bypasses this modeling check; it does
    **not** model the interregional HVDC transfer.

`test/test_hvdc.jl` covers these build success/failure cases. The checks do not
prove complete coverage, disjoint ownership, or conservation for an arbitrary
user partition.

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
fixture-specific; inspect your own System. The active reserve tests verify
regional construction with `RangeReserve`, not general reserve deliverability.

The multistage test fixture explicitly creates `AreaInterchange` components and
assigns each to both subsystems so that their area-balance expressions can use
the interchange. This intentional shared membership is not a general overlap
policy: aggregation can overwrite shared component axes. A vertical
`FixValueFeedforward` fixes interchange values to the producer's decisions.
See [state passing](../explanation/state_passing.md).

## Pre-build checklist

  - Subsystem names match the template keys.
  - Areas, buses, and modeled static injections have the intended membership.
  - Modeled HVDC endpoints satisfy the same-subsystem restriction.
  - Modeled branches have explicit ownership and compatible filters.
  - Services and contributing devices retain their intended associations.
  - Forecast horizon, interval, and resolution cover every execution.
  - Shared memberships have an explicit study rationale; result aggregation is
    not assumed to resolve conflicts.

Do not use `make_subsystems!`, `add_interchanges!`, or `get_jump_models` as
package APIs: those names are defined only by the test utilities.
