# Configure security-constrained reserves

Create generator outages, explicitly select monitoring coverage, and configure
the responding service with `SecurityConstrainedRampReserve`. Follow
[setup](../quick_start_guide.md) and [subsystem assignment](subsystems.md) first.
The runnable example needs the docs environment's solver and case-builder data.

## Separate failure, response, and monitoring

  - The **outaged generator** loses generation in the contingency.
  - The **responding reserve service** supplies the modeled replacement power.
  - The **monitored components** have their post-contingency behavior modeled;
    they are not additional failed equipment.

Attach the same outage attribute to the failed generator and its responding
service within a System. Register a matching named security-constrained
`ServiceModel`. A generator attachment alone does not select a responding service.

An empty monitoring set is **not** shorthand for all components. PowerSystems
accepts an empty set without defining its downstream meaning. In resolved PSI,
an empty set warns and contributes no post-contingency variables or constraints.
A successful solve alone does not establish contingency coverage.

## Choose the monitoring scope

"All" means all **eligible, available, actually modeled components** in the
consuming model, not all devices present in the System.

| Study | Selection | Boundary |
|:----- |:--------- |:-------- |
| Small full-system reference | Explicitly enumerate all eligible modeled AC branches | Useful for validating coverage and comparing restricted selections |
| Regional model | Select eligible branches owned and modeled by that region | Respect branch/network filters; include eligible boundary branches |
| Large targeted study | Select outage/monitor pairs justified by the study | Document exclusions; unmonitored branches have no security coverage claim |
| Whole-system coverage through regional models | Verify coverage across consuming regional models | Do not copy a global branch list blindly into every region |

More outage/monitor pairs increase construction, solve, and storage work.
A subset reduces study coverage; it does not retain an all-branch guarantee.
Monitoring every branch for one generator outage is not enumeration of all outages.

### All eligible regional branches

The example models `Line` and `MonitoredLine`, without additional branch filters,
and assigns branches by from-bus area. Under those explicit assumptions:

```julia
monitored_branches = collect(
    get_components(ACTransmission, sys; subsystem_name="a"),
)
@assert all(get_available, monitored_branches)
@assert all(branch -> branch isa Union{Line, MonitoredLine}, monitored_branches)
@assert !isempty(monitored_branches)
```

For another template, restrict the list to supported modeled types and effective
branch/network filters. Membership alone does not prove eligibility. Omit the
subsystem restriction for a full-system model only after verifying eligibility
against that model. A branch's presence in regional PTDF network context does
not automatically make it an eligible regional monitor.

### A selected subset

Start from the verified eligible list and reject missing requested names:

```julia
eligible_by_name = Dict(get_name(branch) => branch for branch in monitored_branches)
selected_names = ["1_1"]
@assert all(name -> haskey(eligible_by_name, name), selected_names)
selected_branches = [eligible_by_name[name] for name in selected_names]
```

Do not silently intersect an invalid request with available branches: that
silently changes the study's requested coverage.

## Describe and attach outages

The script defines three **example-local helpers**, not exported package APIs:

  - `assign_example_subsystems!` assigns areas, buses, injections, and branches.
  - `make_outage_specifications` returns typed named tuples describing failed
    generator names, responding reserve types/names, and explicit monitor names.
  - `add_outages_to_systems!` resolves the specifications separately in each
    System and attaches one outage object to its generators and services.

For example, this specification selects one monitored line rather than all
eligible lines. Use it instead of that region's all-branch specification in a
fresh run, not as an additional duplicate outage:

```julia
specification = (
    outage_generators=["Sundance_1"],
    responding_reserves=Dict{DataType, String}(VariableReserve{ReserveUp} => "Reserve1_1"),
    monitored_components=["1_1"],
)
```

Monitoring names in these helper specifications are resolved to actual devices
before `GeometricDistributionForcedOutage` is constructed. The PowerSystems
constructor accepts device objects or UUIDs and stores UUIDs internally.
Resolve components in each independently created System: matching names do not
guarantee matching UUIDs. Preserve the reserve's contributing-device associations
and assign/register its service in the intended region.

## Configure before constructing the DecisionModel

To replace an existing outage's monitoring set before model construction:

```julia
set_monitored_components!(outage, selected_branches)
```

`add_monitored_components!` adds to the current set;
`clear_monitored_components!` empties it and does not enable all-component
monitoring. These are PowerSystems APIs.

After constructing a `DecisionModel`, recreate it from the updated System and
template if monitoring changes. Regional finalization has already populated
outage metadata; changing the System does not refresh that metadata or existing
constraints. Users should not call PSI's internal metadata builders themselves.

## Run the complete example

The script follows the active two-area 10-bus regression. It uses dispatch,
not unit commitment. Region a monitors six internal lines and
`inter_area_line`; b monitors six internal lines.

The fixture removes thermal ramp limits and makes both Sundance generators
must-run at a minimum of 1.0 system-base p.u. These demonstration assumptions
isolate contingency/export behavior; they are not production operating data or
proof of central/decomposed equivalence. Outage parameters are fixture values,
not a stochastic reliability simulation.

From the repository root:

```powershell
julia --project=docs docs\examples\security_constrained_reserves.jl
# Checked two generator outages, 13 monitored branch/outage pairs, and 24 hourly results.
```

The script checks successful build/solve statuses, exact outage/branch identities,
all 24 time indices, finite flows, and reserve-deployment conservation. The raw
standalone values used by its checks are system-base p.u.; see
[contingency results](results.md#Contingency-flow-results).

```@eval
using Markdown
Markdown.MD([
    Markdown.Code(
        "julia",
        read(joinpath(@__DIR__, "..", "..", "examples", "security_constrained_reserves.jl"), String),
    ),
])
```

```@example security_constrained_reserves
include(joinpath(@__DIR__, "..", "..", "examples", "security_constrained_reserves.jl")) # hide
nothing # hide
```

## Adapt the monitoring policy

The RTS regression monitors `CA-1` and `A28` for the outage of `313_CC_1` and
response service `Spin_Up_R3`. Its existing to-bus ownership assigns both lines
to subsystem a, containing areas 1 and 3; `CB-1` and `AB1` belong to b. That is
different from the example's from-bus policy. Do not assume internal-only
monitoring or reverse branch orientation to change ownership.

RTS checks five realized flow rows against solved regional expressions in MW
and preserves reserve-deployment conservation checks. Its in-memory multistage
configuration does not establish support for every storage/realized-reader path.

## Troubleshoot missing coverage

| Symptom | Check and recovery |
|:------- |:------------------ |
| Empty-monitor warning | Supply a nonempty explicit eligible set; empty does not mean all |
| No deployment or flow key | Check generator/service attachments and the matching named security-constrained service model |
| Missing branch or monitor | Check availability, modeled types, filters, ownership, and System UUID identity; recreate the model |
| Warning about an unmodeled responding service | Regional validation can see another region's service; verify the intended region's keys and coverage rather than dismissing all warnings |
| Missing `AreaInterchange` monitor under PTDF | That path does not build these tie-flow expressions; see the network-specific reference |

Read [security-constrained integration](../formulation_library/security_constrained.md)
for formulation-specific limits and the distinction between observing a flow
and enforcing its rating.