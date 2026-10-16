# Released dependency upgrade: diagnosis and fix plan

## Scope and current result

Validated on 2026-10-15, Windows, Julia 1.13.2, branch `sm/up_depends`.
Update the released dependency baseline without changing physical models,
subsystem ownership, feedforward semantics, solver choice, or numerical tolerances.
Leave fixes proposed below unimplemented pending approval. Do not publish a PR
until the runtime and documentation checks both pass.

The dependency changes and initial diagnosis were committed and pushed in
sequential slices on explicit user authorization, despite the documented docs
blocker. Publishing this branch is not a claim that documentation validation
passes, and it does not implement or authorize the proposed modeling-code fixes.

The [root project](../Project.toml), [test project](../test/Project.toml), and
[docs project](Project.toml) now require the latest non-yanked, non-prerelease
Sienna releases available in the refreshed General registry:

| Package                   | Released target resolved |
|:------------------------- |:------------------------ |
| PowerSimulations          | 0.38.4                   |
| PowerSystems              | 5.12.3                   |
| PowerNetworkMatrices      | 0.24.4                   |
| InfrastructureSystems     | 3.6.3                    |
| PowerFlows                | 0.25.3                   |
| PowerSystemCaseBuilder    | 2.6.1                    |
| HydroPowerSimulations     | 0.19.1                   |
| StorageSystemsSimulations | 0.20.0                   |

Compatibility bounds allow subsequent compatible releases, not development
branches or exact-version pins. PowerFlows is a root transitive dependency and
an explicit test dependency; hydro/storage are test dependencies.

PowerSimulations 0.38.4 requires Julia 1.10+, JuMP 1.28+, and DataStructures
0.18 or 0.19. The latest PowerSystems, PowerNetworkMatrices, and PowerFlows
require DataStructures 0.19, narrowing the combined requirement. The resolved
environment uses DataStructures 0.19.6, JuMP 1.32.1, MathOptInterface 1.54.0,
DocStringExtensions 0.9.5, and MPI 0.20.29. Documenter remains at 0.27.25:
no Sienna dependency requires upgrading it.

## Validation evidence

Commands were run from the repository root with automatic package precompilation
disabled (`$env:JULIA_PKG_PRECOMPILE_AUTO='0'`). The docs build also used
`$env:DOCS_DEPLOY='false'`; no deployment occurred.

| Exact command                                                                                                                            | Result                                                                                                                                      |
|:---------------------------------------------------------------------------------------------------------------------------------------- |:------------------------------------------------------------------------------------------------------------------------------------------- |
| `julia --startup-file=no --project=. -e 'using Pkg; Pkg.update(); Pkg.status()'`                                                         | Passed; root environment resolves to the released targets.                                                                                  |
| `julia --startup-file=no --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.update(); Pkg.status()'`                | Passed; docs environment resolves to the same released targets.                                                                             |
| `julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'`                                                                         | Passed; 281/281 enabled suite assertions plus the configured Aqua checks.                                                                   |
| `julia --startup-file=no --project=docs docs\examples\decomposition.jl`                                                                  | Passed; both regional models solve, with 24 hourly rows, all thermal generators, finite dispatch, and the existing nonnegativity tolerance. |
| `julia --startup-file=no --project=docs docs\make.jl`                                                                                    | Failed twice; the tutorial example raises `KeyError: key Symbol("PowerSystems.MonitoredLine") not found`.                                   |
| `julia --startup-file=no --project=docs -e 'module TutorialSandbox; include(joinpath(pwd(),"docs","examples","decomposition.jl")); end'` | Failed with the same error and a full stack trace locating the local defect.                                                                |
| `git --no-pager diff --check`                                                                                                            | Passed.                                                                                                                                     |

The full suite runs component assignment, horizontal passing, HVDC, hydro,
reserves, and vertical passing. The existing reserve-deliverability exclusion
in [the test harness](../test/runtests.jl) remains unchanged. MPI execution and
other operating systems/Julia versions were not validated.

Ignored local manifests were resolved by Pkg and are not publication artifacts.
Pkg initially warned about stale test-manifest entries, then successfully
re-resolved hydro/storage and the remaining test environment. These warnings
did not prevent testing the requested releases. Pkg-generated `[sources]`
entries were removed from the tracked projects after validation, including an
absolute local path; no dependency bounds were changed by that cleanup.

## Confirmed failure and ownership

**Owner: PowerSimulationsDecomposition.jl, not PowerSystems, PowerSimulations,
PowerSystemCaseBuilder, or Documenter.**

### Where the documentation build fails

The documentation is an integration test, not just rendered prose.
[The tutorial page](src/tutorials/intro_page.md) executes
[the example](examples/decomposition.jl) inside a named Documenter `@example`
block. Documenter 0.27.25 evaluates that block inside a sandbox module using
`Core.eval(mod, ex)`, rather than evaluating its imports in `Main`.

The example creates a base template with Line and MonitoredLine models and a
regional template for each subsystem. Under the existing from-bus ownership
rule, subsystem `b` has no MonitoredLine components. Removing that unused
regional model is expected behavior, not missing fixture data or a reason to
change component ownership.

The failing execution path is:

```text
docs/make.jl: strict makedocs
  -> docs/src/tutorials/intro_page.md: @example decomposition
  -> docs/examples/decomposition.jl: DecisionModel(...)
  -> src/problems/multi_region_problem.jl: copy and finalize template
  -> src/multiproblem_template.jl: finalize each regional template
  -> _add_modeled_ac_branches!: remove unused MonitoredLine model
  -> pop!(branch_models, Symbol(component_type))
  -> KeyError: key Symbol("PowerSystems.MonitoredLine") not found
```

The error occurs during `DecisionModel` construction, before the example calls
`build!` or `solve!`. It is not solver infeasibility, a PTDF numerical error,
result aggregation, or an HTML rendering problem. Documenter's strict build
correctly reports the failed example and terminates before rendering.

### Why the dictionary keys disagree

Released PowerSimulations 0.38.4 inserts device/branch keys using
`Symbol(IS.strip_module_name(D))` in
[device_model.jl](https://github.com/Sienna-Platform/PowerSimulations.jl/blob/v0.38.4/src/core/device_model.jl)
and retrieves them the same way in
[problem_template.jl](https://github.com/Sienna-Platform/PowerSimulations.jl/blob/v0.38.4/src/operation/problem_template.jl).
For MonitoredLine, the stored key is always `:MonitoredLine`.

Local pruning instead uses `Symbol(component_type)`. This constructs a symbol
from the type's textual representation; it is not a stable type identifier.
When MonitoredLine is not imported into `Main`, the representation includes its
module prefix. Symbols do not normalize that prefix:
`:MonitoredLine` and `Symbol("PowerSystems.MonitoredLine")` are distinct keys.
The component type itself has not changed; only its textual qualification has.

A fresh-process probe with imports confined to a module confirms:

```text
stored keys: [:MonitoredLine]
Symbol(MonitoredLine): Symbol("PowerSystems.MonitoredLine")
nameof(MonitoredLine): :MonitoredLine
Symbol key exists: false
nameof key exists: true
```

A control probe in a separate process, with `using PowerSystems` in `Main`,
produces `:MonitoredLine` for both the stored key and `Symbol(MonitoredLine)`.
Both probes use the same released packages; no fixture, solver, or dependency
version changes are needed to switch between the two outcomes.

### Why the full test suite and standalone example pass

[The test harness](../test/runtests.jl) imports PowerSystems into `Main` before
including the tests. Running the tutorial directly as a script does the same.
Those imports make the local display-dependent key happen to match the
upstream stored key. Documenter's sandbox imports do not establish the same
bindings in `Main`, exposing the mismatch.

Therefore, the 281 passing assertions and the failing docs build are consistent:
they exercise different module/import contexts. Adding another nested module
to the existing test process would not reliably expose the defect, because
the harness has already populated `Main`. A fresh child process is required
for the regression test.

### The failure is broader than branch pruning

The same mismatch appears in related local device/branch code:

| Surface                        | Current local operation                                | Consequence in isolated use                                                                                            |
|:------------------------------ |:------------------------------------------------------ |:---------------------------------------------------------------------------------------------------------------------- |
| Regional branch pruning        | `pop!(branch_models, Symbol(component_type))`          | Confirmed KeyError for the unused MonitoredLine model.                                                                 |
| Base/regional model retrieval  | `get(models, Symbol(T), nothing)`                      | Confirmed false absence: upstream retrieves ThermalStandard, but both local multi-template overloads return `nothing`. |
| Empty device-model pruning     | `pop!(device_models, Symbol(component_type))`          | Same key mismatch; add a dedicated empty-device regression before fixing.                                              |
| Injector/bus consistency guard | `Symbol(typeof(si))` membership in modeled-device keys | Can fail to recognize a modeled injector, bypassing the bus-consistency check; add a negative regression.              |

The first two outcomes were reproduced. The last two are coupled risks inferred
from the same key construction, not additional failures observed in the full
suite. They belong in the fix scope because fixing only MonitoredLine removal
would leave module-context-dependent behavior elsewhere.

The evidence identifies a local extension/API mismatch with PSI 0.38.4. It does
not establish the first release or commit that introduced the mismatch, nor
that every older dependency combination is affected.

## Recommended implementation design

Make template access independent of imports into `Main`, while retaining the
existing device, branch, and service contracts.

### Delegate model retrieval to PowerSimulations

The two local `PSI.get_model` overloads in
[multiproblem_template.jl](../src/multiproblem_template.jl) should select the
appropriate upstream `PSI.ProblemTemplate` and delegate retrieval to PSI:

```text
base lookup     -> PSI.get_model(template.base_template, T)
regional lookup -> PSI.get_model(template.sub_templates[subsystem], T)
```

These are proposed replacements, not implemented changes. The delegated receiver
is a `PSI.ProblemTemplate`, so dispatch selects upstream's method rather than
recursing into the `MultiProblemTemplate` overload. Preserve `nothing` for an
absent device model and the existing error for an unknown subsystem.

### Remove models using their actual stored keys

For empty-device and branch pruning, iterate over a snapshot of the dictionary
entries, retaining each `(key, model)` pair. Check component availability using
the same existing subsystem filter and remove absent models by that stored
`key`. Snapshotting entries also avoids mutating a dictionary during traversal
of its live values iterator.

This approach does not need to reconstruct a key at all. If reconstruction is
required elsewhere, use the same `Symbol(IS.strip_module_name(T))` conversion as
the resolved upstream implementation. Although `nameof(MonitoredLine)` happens
to produce the right key here, it is not a general substitute for PSI's
normalization contract, particularly for parameterized types.

Preserve the current warning, branch ownership, modeled-branch type registration,
and removal of only regionally absent components. Do not suppress the KeyError
with a default-valued `pop!`: that could leave the unused model in the template
while hiding the mismatch.

### Recognize modeled injectors through the same contract

In [sequential_algorithm.jl](../src/algorithms/sequential_algorithm.jl), use
upstream model retrieval or upstream-normalized device keys to decide whether
an injector is modeled. Then retain the current explicit bus-membership check
and `ConflictingInputsError`. This is a validation correction, not a new
subsystem policy.

Keep service lookup separate. Released PSI's service keys still use
`(service_name, Symbol(D))`; a repository-wide replacement of `Symbol(Type)`
would mix two different upstream contracts and could break reserve/feedforward
attachment.

## Ordered fix plan

 1. **Add failing regression coverage here.** Extend
    [component-assignment tests](../test/test_component_assignment.jl) with a
    fresh-process, module-isolated fixture that does not import PowerSystems
    into `Main`. Reproduce branch pruning and base/regional model retrieval.
    A nested module inside the current test process alone is insufficient:
    the harness already imports the types into `Main`.
 2. **Align device/branch keys here.** In
    [multiproblem_template.jl](../src/multiproblem_template.jl), delegate
    base/regional retrieval to upstream `PSI.get_model` where possible.
    For empty-device and branch pruning, use the actual stored dictionary keys
    or upstream's `Symbol(IS.strip_module_name(T))` contract. Preserve explicit
    missing-model behavior and existing subsystem filtering.
 3. **Cover the coupled membership guard here.** In
    [sequential_algorithm.jl](../src/algorithms/sequential_algorithm.jl),
    `Symbol(typeof(si))` uses the same display-dependent device-key construction.
    Align it with upstream and add a fresh-process negative test proving a
    modeled injector assigned away from its bus still raises the intended
    `ConflictingInputsError`. This bypass risk follows from the key mismatch;
    it is not an additional failing assertion observed in the existing suite.
 4. **Preserve service contracts.** Audit the related service matching in
    [multi_region_problem.jl](../src/problems/multi_region_problem.jl), but do
    not mechanically replace every `Symbol(Type)`: released PSI's service
    dictionary still uses `(service_name, Symbol(D))`, unlike device dictionaries.
    Run reserve/feedforward regressions if service matching changes.
 5. **Validate fixes before opening a PR.** Run the focused
    component-assignment/HVDC regressions, the module-isolated reproducer, the
    full suite, the standalone tutorial, and the strict docs build. Use the
    existing formatter for any changed Julia code. Update the temporary
    validation warnings in the README and support manual after the blocker
    is fixed. Commit and push the fixes separately from the already-published
    dependency and documentation changes, then open the authorized PR against
    `main` using the repository template.

No upstream fix is required by the evidence collected. Do not work around the
failure by disabling strict docs, skipping the example, removing MonitoredLine
from the tutorial, importing packages into `Main` solely to affect display, or
downgrading the requested releases.

## Regression execution and verification

Add a proposed fresh-process fixture under `test/test_utils/` and invoke it
from the component-assignment tests using `Base.julia_cmd()`. Select the active
Pkg test sandbox with `--project` and disable startup files. Do not launch the
fixture in an unprepared `--project=test` environment or import PowerSystems
into the child's `Main`; its imports must remain inside its test module.

The child should verify successful base/regional lookup, unused branch and
empty-device pruning, and rejection of an inconsistent injector/bus assignment.
Check its exit status in the parent test. Keep a control scenario with imports
in `Main` to ensure the fix preserves existing supported usage.

After implementing the fix, run from the repository root:

```powershell
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test(; test_args=["test_component_assignment", "test_hvdc"])'
julia --startup-file=no --project=docs -e 'module TutorialSandbox; include(joinpath(pwd(),"docs","examples","decomposition.jl")); end'
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
julia --startup-file=no --project=docs docs\examples\decomposition.jl
$env:DOCS_DEPLOY='false'
julia --startup-file=no --project=docs docs\make.jl
git --no-pager diff --check
```

These are future acceptance commands, not a claim of passing results for an
unimplemented fix. The original measured outcomes are recorded above. During
the explanation update, fresh-process key probes again confirmed both the
isolated mismatch and the matching-key control with imports into `Main`;
no modeling code or dependency bounds changed, so the full suite was not rerun.

## Acceptance criteria for the fix

  - Root, test, and docs environments still resolve to the released Sienna targets.
  - Device/branch lookup and regional pruning work with and without imports into
    `Main`; absent regional models are removed without a KeyError.
  - Static-injector/bus assignment validation cannot be bypassed by module context.
  - Existing 281 suite assertions and the new regressions pass; intentionally
    disabled reserve-deliverability tests remain disabled.
  - The isolated tutorial and strict docs build pass without weakening checks.
  - Existing dispatch coverage, 24-hour chronology, status assertions, finite
    values, and nonnegativity tolerance remain unchanged.
