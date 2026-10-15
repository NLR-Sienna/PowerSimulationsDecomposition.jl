# Developer guide

Read the [lifecycle](architecture.md) before changing extension dispatch, and
the [workflow](workflow.md) before selecting checks. Computational behavior lives
in Julia source and tests; this manual is not a substitute for verifying the
resolved PowerSimulations 0.34.x interfaces.

## Run the local development checks

Start from the repository root in PowerShell with Julia 1.10+ (the documentation
CI uses Julia 1.11). The [local development cycle](workflow.md#Local-development-cycle)
provides a copyable runbook:

| Task                            | Instructions                                                                                                 |
|:------------------------------- |:------------------------------------------------------------------------------------------------------------ |
| Format Julia and Markdown       | [Run the repository formatter](workflow.md#Formatting); it modifies files across the checkout                |
| Run regression tests            | [Run all tests or select test files](workflow.md#Tests), including the runner's Aqua checks                  |
| Prebuild and preview the manual | [Build documentation locally](workflow.md#Build-documentation-locally); the build also executes the tutorial |

Inspect the resulting diff before committing. A successful local prebuild does
not deploy the manual or prove that remote CI passed.

## Repository map

Paths below are relative to the repository root.

MPI means **Message Passing Interface**, the interprocess communication standard
used by `MPI.jl`. The MPI files below are incomplete parallel-execution scaffolding,
not an alternative supported algorithm.

| Path                                                  | Responsibility / status                                                                                  |
|:----------------------------------------------------- |:-------------------------------------------------------------------------------------------------------- |
| `src/PowerSimulationsDecomposition.jl`                | Five exports, dependency imports/aliases, docstring template, and active include order                   |
| `src/core/algorithms.jl`                              | Internal algorithm abstract type and sequential/MPI tags                                                 |
| `src/core/definitions.jl`                             | Joint-store field lists and concrete HVDC-type symbols                                                   |
| `src/core/formulations.jl`                            | Split-area network and state-estimation branch formulation types                                         |
| `src/core/parameters.jl`                              | Internal baseline injection/flow parameter types                                                         |
| `src/core/constraints.jl`                             | State-estimation flow constraint key                                                                     |
| `src/core/mpi_info.jl`                                | MPI communicator metadata; rank is converted to one-based indexing                                       |
| `src/core/auxiliary_variables.jl`                     | Empty included scaffold                                                                                  |
| `src/multiproblem_template.jl`                        | Template ownership, setters/accessors, regional finalization                                             |
| `src/multi_optimization_container.jl`                 | Regional/main containers, shared typed stores, settings, initialization, PSI accessors                   |
| `src/problems/multi_region_problem.jl`                | PSI DecisionModel constructor/build/solve/update extensions, joint axes, feedforwards, state integration |
| `src/algorithms/sequential_algorithm.jl`              | Active regional build/solve and result-copy path, membership checks                                      |
| `src/algorithms/mpi_parallel_algorithm.jl`            | Included but incomplete MPI scaffold; not selected by public construction                                |
| `src/models/network_models.jl`                        | Area/nodal balances, state-estimation injections, parameter updates                                      |
| `src/models/branch_models.jl`                         | Monitored-line baseline flows and PTDF flow-expression reconstruction                                    |
| `src/print.jl`                                        | Text display of templates and multi-region models                                                        |
| `src/multi_decision_model.jl`                         | Empty and not included by the entry point                                                                |
| `test/runtests.jl`                                    | Imports, Aqua subset, logging, test-file selection and disabled-file list                                |
| `test/Project.toml`                                   | Test-only dependencies, including solver, fixtures, hydro/storage extensions, and Aqua                   |
| `test/test_*.jl`                                      | Component, HVDC, reserve, hydro, horizontal/vertical regression cases                                    |
| `test/test_utils/`                                    | Fixture modifications, model checks, multistage simulation helper; not public API                        |
| `docs/src/`                                           | Navigated user/developer Markdown, API blocks, Mermaid initialization asset                              |
| `docs/examples/decomposition.jl`                      | Runnable tutorial, executed by Documenter                                                                |
| `docs/make.jl`                                        | Strict Documenter build, navigation, opt-in deployment configuration                                     |
| `docs/Makefile`                                       | Optional local `html` target, run from `docs`; no publication target                                     |
| `scripts/formatter/formatter_code.jl`                 | Repository-wide Julia/Markdown formatting script                                                         |
| `Project.toml`                                        | Computational dependencies and compatibility; test prerequisites live in the separate test project       |
| `docs/Project.toml`                                   | Documenter, local package, solver and fixture prerequisites                                              |
| `scripts/formatter/Project.toml`                      | JuliaFormatter tooling environment                                                                       |
| `.editorconfig`                                       | LF, final newline, four-space Julia indentation                                                          |
| `.gitignore`                                          | Generated manifests, logs, data, model outputs, documentation builds, local editor state                 |
| `codecov.yml`                                         | Coverage status thresholds and reporting configuration                                                   |
| `CONTRIBUTING.md`, `.github/pull_request_template.md` | Contribution entry point and PR checklist                                                                |
| `README.md`, `LICENSE`                                | Project entry point and unchanged legal terms                                                            |
| `.github/agents/`, `.github/skills/`                  | Repository-specific assistant workflows, not runtime package code                                        |

There is no checked-in dependency manifest. Local `Manifest.toml` files are
ignored resolver output, not guarantees that everyone uses the same patch
versions. Record resolved versions when reporting numerical regressions.

## Workflow map

| Workflow                 | Current responsibility / caveat                                                                                                                                                 |
|:------------------------ |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `main-tests.yml`         | Main-branch/scheduled tests on Linux, Windows, macOS with stable/nightly Julia; coverage upload. GitHub reported it disabled for inactivity during documentation investigation. |
| `pr_testing.yml`         | PR test matrix and coverage                                                                                                                                                     |
| `docs.yml`               | Julia 1.11 docs build, executable tutorial, uploaded HTML artifact; no automatic deployment                                                                                     |
| `format-check.yml`       | Run formatter and fail on a nonempty diff; PR suggestions                                                                                                                       |
| `cross-package-test.yml` | Legacy downstream checks; push trigger still uses `master`, old owner references, and allows incompatibility failures. Not evidence of full cross-package support.              |
| `TagBot.yml`             | TagBot on authorized issue-comment/manual events; uses repository credentials                                                                                                   |

Some workflows use older actions and runtime choices. This documentation change
does not modernize unrelated testing/release automation or enable disabled jobs.
Repository owners control secrets, Pages configuration, and deployment.

## Reading order

The entry point imports dependencies and declares aliases before including core
types, templates/containers, algorithms, the DecisionModel extension, network/
branch methods, and display methods. Add new definitions before their consumers,
and verify the exact PSI method signatures against the resolved dependency.

Continue with [Extension lifecycle](architecture.md),
[Workflow and validation](workflow.md), and [Style guide](style.md).
