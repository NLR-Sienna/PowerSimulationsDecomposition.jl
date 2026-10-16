# Released dependency upgrade: diagnosis and fix plan

## Scope and current result

Validated on 2026-10-15, Windows, Julia 1.13.2, branch `sm/up_depends`.
Update the released dependency baseline without changing physical models,
subsystem ownership, feedforward semantics, solver choice, or numerical tolerances.
Leave fixes proposed below unimplemented pending approval. Do not publish a PR
until the runtime and documentation checks both pass.

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

The tutorial reaches `DecisionModel` construction at
[the example](examples/decomposition.jl). That calls `finalize_template!` and
then `_add_modeled_ac_branches!` in
[multiproblem_template.jl](../src/multiproblem_template.jl).
Removing the absent regional MonitoredLine model calls
`pop!(branch_models, Symbol(component_type))`.

Released PowerSimulations 0.38.4 inserts device/branch keys using
`Symbol(IS.strip_module_name(D))` in `src/core/device_model.jl` and retrieves
them the same way in `src/operation/problem_template.jl`. Local code instead
uses `Symbol(T)`, whose string representation depends on imports visible in
`Main`. A module-isolated probe confirms:

```text
stored keys: [:MonitoredLine]
Symbol(MonitoredLine): Symbol("PowerSystems.MonitoredLine")
nameof(MonitoredLine): :MonitoredLine
Symbol key exists: false
nameof key exists: true
```

The same probe for ThermalStandard confirms that upstream base-template
`get_model` returns a model, while both local multi-template lookup overloads
return `nothing`. Existing tests import PowerSystems into `Main`, masking this
context-sensitive mismatch. Running the example as a standalone script also
imports into `Main`, explaining why it succeeds while Documenter fails.

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
 5. **Validate and publish only after green checks.** Run the focused
    component-assignment/HVDC regressions, the module-isolated reproducer, the
    full suite, the standalone tutorial, and the strict docs build. Use the
    existing formatter for any changed Julia code. Update the temporary
    validation warnings in the README and support manual after the blocker
    is fixed. Then commit, push, and open the authorized PR against `main`
    using the repository template.

No upstream fix is required by the evidence collected. Do not work around the
failure by disabling strict docs, skipping the example, removing MonitoredLine
from the tutorial, importing packages into `Main` solely to affect display, or
downgrading the requested releases.

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
