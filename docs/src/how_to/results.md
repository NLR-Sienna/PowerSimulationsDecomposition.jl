# Read results

Use PowerSimulations' result interfaces after checking build and execution
statuses. A returned model or an output directory alone does not prove a
successful solve.

## Standalone decision problem

The [tutorial](../tutorials/intro_page.md) creates `problem` and checks the statuses:

```julia
@assert build!(problem; output_dir=mktempdir()) == PowerSimulations.ModelBuildStatus.BUILT
@assert solve!(problem) == PowerSimulations.RunStatus.SUCCESSFULLY_FINALIZED
results = OptimizationProblemResults(problem)
list_variable_names(results)
dispatch = read_variable(
    results,
    ActivePowerVariable,
    ThermalStandard;
    table_format=TableFormat.WIDE,
)
```

Use the typed reader for standalone results: this package's joint container does
not populate all string-key lookup metadata, so a listed name can still fail
with `"is not stored"` when passed to the string reader.
In wide format, the returned DataFrame has a `DateTime` column and component
columns. PSI defaults to long format; specify `TableFormat.WIDE` when using
the component-column indexing shown in this manual.

## Simulation results

For a successfully executed PSI `Simulation` called `sim`:

```julia
results = SimulationResults(sim)
regional = get_decision_problem_results(results, "UC_Subsystem")
list_variable_names(regional)
list_parameter_names(regional)
list_expression_names(regional)

injections = read_realized_parameter(
    regional,
    "StateEstimationInjections__ACBus";
    table_format=TableFormat.WIDE,
)
balances = read_realized_expression(
    regional,
    "ActivePowerBalance__ACBus";
    table_format=TableFormat.WIDE,
)
```

`"UC_Subsystem"` is the name assigned in the multistage test fixture, not a
required name. Use your model's name and discover the available keys first.
State-estimation flows exist only when the corresponding monitored-line
formulation is modeled.

The tests also use PSI's `read_realized_variable` convenience reader for
expression and parameter names. For new code, prefer the category-specific
parameter/expression readers above. Realized readers assemble the executed
intervals; use `read_variable`/`read_parameter`/`read_expression` for individual
forecast windows instead.

## Contingency-flow results

Follow [Configure security-constrained reserves](security_constrained_reserves.md)
to create `results`, the typed outage specifications, and their attached outages.
Discover keys first: a successful solve does not prove the requested monitors
were constructed. The standalone example uses typed optimization keys rather
than incomplete string-key metadata:

```julia
flow_key = PowerSimulations.ExpressionKey{
  PostContingencyBranchFlow, VariableReserve{ReserveUp},
}("Reserve1_1")
flows = get_expression_values(results)[flow_key]
```

These raw standalone sparse-flow tables contain `time_index`, `name`, and
`value`. The encoded name is `outage_uuid * "__" * branch_name`, not a separate
`name2` branch field. Use the full identity; suffix-only matching can conflate
outages. The example obtains the UUID with `InfrastructureSystems.get_uuid`
and asserts the exact requested names and every hourly entry. These raw values
are system-base p.u., unlike public readers that apply entry-specific conversions.

For the active RTS simulation fixture:

```julia
regional = get_decision_problem_results(results, "UC_Subsystem")
flows = read_realized_expression(
  regional,
  "PostContingencyBranchFlow__VariableReserve__ReserveUp__Spin_Up_R3";
  table_format=TableFormat.WIDE,
)
```

Here `results` is the simulation result object, not the standalone object above.
The returned table has `DateTime` plus encoded outage/branch columns. The RTS
regression checks exactly `CA-1` and `A28`, finite values, five realized times,
dispatch-aligned timestamps, and exported MW flows against solved regional
expressions multiplied by System base power. Do not generalize this conversion
to every result entry. Public long-format flow readers use `DateTime`, `name`,
and `value`; dense multidimensional deployment tables have a different schema.

## What is aggregated

The regional solves keep their own JuMP containers. Before PSI stores results,
`write_results_to_main_container` copies numeric values into joint arrays keyed
by PSI optimization keys:

  - Dense variables, auxiliary variables, expressions, constraints, and duals
    have joint axes; copying handles one, two, and three dimensions.
  - Active-power-balance expressions at AC buses copy only the buses assigned to
    each region, using `subproblem_bus_map`.
  - Sparse variable, auxiliary-variable, expression, constraint, and dual stores
    preserve the union of actual regional tuple keys and copy evaluated values.
    No missing outage/branch combinations are invented or filled with zero.
  - Parameters and multipliers are copied separately; more than two dimensions
    raises an error.

There is no regional dimension added to the public result table. **Do not sum
duplicate shared component columns** as though they were distinct physical
assets. General overlapping axes can be overwritten as the dictionary is
iterated. Mixed dense/sparse representations for one result key are rejected.
Sparse result support does not add sparse parameter support. Parameter attribute merging rejects
incompatible metadata and colliding time-series component mappings.

The `main_problem` container is not a solved central coordination problem.
Aggregated objective/optimizer statistics should not be interpreted as a
certified central optimum or a complete per-region performance report.

## Units and comparisons

Initialization sets the System to `SYSTEM_BASE`; internal power quantities use
the System's per-unit base. Result conversion is controlled by PSI's entry-type
conversion methods, not by a blanket conversion applied here. Custom
state-estimation parameter/expression entries do not acquire MW units merely
because a reader returns a DataFrame.

Check the key's conversion behavior in the resolved PSI version before comparing
it with MW data or multiplying by `get_base_power(sys)`. Retain timestamps,
component identities, bases, and branch orientation when comparing producer and
consumer states. The horizontal tests compare offset rows; vertical tests
compare matching rows. See [state passing](../explanation/state_passing.md).
