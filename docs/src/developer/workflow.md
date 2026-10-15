# Workflow and validation

Use a branch from `main`, preserve unrelated/staged changes, and inspect
`Project.toml`, the active manifest, source, tests, and workflows before editing.
Computational compatibility stays at PSI 0.34.x unless a separate upgrade is
approved.

## Local development cycle

Run the following from the **repository root in PowerShell**. Use a compatible
Julia installation (1.10+); if multiple versions are installed with Juliaup,
replace `julia` with `julia +1.11` to select the documentation CI's minor version.

### Step 1: Format

Format Julia source and Markdown using the repository script:

```powershell
julia -e 'include(joinpath("scripts", "formatter", "formatter_code.jl"))'
git diff --check
git diff --stat
```

The formatter activates its own environment and modifies the entire checkout.
Review changes before staging; preserve unrelated local work. See
[Formatting](#Formatting) for scope and configuration.

### Step 2: Test

Test the affected behavior. For example, select the membership and HVDC
regressions:

```powershell
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test_component_assignment", "test_hvdc"])'
```

Use `julia --project=. -e 'using Pkg; Pkg.test()'` to run all enabled test
files. Both commands also run the configured Aqua checks; reserve-deliverability
tests remain disabled. See [Tests](#Tests) for the regression-selection table.

### Step 3: Prebuild and preview

Prebuild and preview the documentation without deploying:

```powershell
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); Pkg.status()'
julia --project=docs docs\make.jl
Start-Process .\docs\build\index.html
```

The strict build executes the tutorial and checks documented exports and
references. Open the generated site to check navigation, diagrams, and both
themes. Keep `DOCS_DEPLOY` unset; deployment is a separate authorized action.
See [Build documentation locally](#Build-documentation-locally) for details.

Record commands, Julia/package versions, outcomes, and any unverified checks in
the PR. Formatting, passing model tests, and an HTML build verify different
surfaces; none substitutes for the others.

## Build documentation locally

From the repository root in PowerShell:

```powershell
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); Pkg.status()'
julia --project=docs docs\make.jl
```

`docs/make.jl` uses Documenter 0.27, strict checking, all five exported bindings,
and explicit navigation. The tutorial executes as an `@example` block using
`docs/examples/decomposition.jl`. A successful build creates `docs/build/index.html`.
Local builds use non-pretty URLs so pages can also be opened directly.
The optional `make html` target is run from `docs`, not the repository root.

To run only the example:

```powershell
julia --project=docs docs\examples\decomposition.jl
```

### Diagrams and links

Mermaid fences remain readable on GitHub. Documenter HTML loads pinned Mermaid
11.4.1 from jsDelivr plus `docs/src/assets/mermaid.js`, which replaces those
code blocks with rendered diagrams. The browser needs access to that CDN. Diagrams use a white panel to retain
contrast in both Documenter themes. Edit-page links are disabled so local/PR
builds do not advertise new pages as already present on `main`.
An HTML build alone does not prove diagrams rendered: inspect the generated
pages in a browser, check for SVGs and console errors, and check both light and
dark document themes. GitHub's own Mermaid version can differ; inspect the
branch Markdown preview separately when available.

Documenter validates local links and `@ref` targets during the strict build.
External services may reject automated link requests; distinguish a verified
destination, an inaccessible service, and a confirmed 404 instead of calling all
three valid.

### CI and deployment

The documentation workflow builds on PRs and pushes to `main`, release branches,
and tags, then uploads the HTML site as an artifact. It does **not** deploy.
Build-only checks need no write credentials.

`docs/make.jl` retains an opt-in `DOCS_DEPLOY=true` path for authorized
maintainers, targeting `github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git`,
`gh-pages`, development branch `main`, development URL `dev`, and tagged
`stable`/version URLs. Previews are disabled. Enabling this is a publication
action requiring repository credentials and configured GitHub Pages, not a
normal local validation command. No existing stable/dev site is assumed.

## Tests

The intended clean-package command is:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

The current test runner consumes filenames without extensions through `ARGS`:

```powershell
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test_component_assignment", "test_hvdc"])'
```

The runner performs Aqua checks before file selection. It also skips
`test_reserve_deliverability.jl` even if explicitly selected.

`test/Project.toml` declares PowerSystemCaseBuilder, HydroPowerSimulations,
StorageSystemsSimulations, TimeSeries, HiGHS, JuMP, Aqua, and the other test
prerequisites. Prefer `Pkg.test()` so the test project and package under test
are resolved together; do not assume `julia --project=test` recreates that
sandbox. Report resolver/import failures separately from model assertions and
never edit installed dependencies to make a test pass.

| Changed surface                                    | Relevant files                                                 |
|:-------------------------------------------------- |:-------------------------------------------------------------- |
| Template membership, branch filtering              | `test_component_assignment`, `test_hvdc`                       |
| Static injection and bus consistency, modeled HVDC | `test_hvdc`                                                    |
| Service propagation and regional reserves          | `test_reserves`                                                |
| Parameter sources, chronology, monitored-line flow | `test_horizontal_passing`, `test_vertical_passing`             |
| Hydro budgets and one-dimensional results          | `test_hydro`                                                   |
| Reserve deliverability                             | Disabled; do not enable without investigating its requirements |

For model changes, assert build/run statuses, membership, flow orientation,
power/energy bases, dimensions, and finite values. Use justified `atol`/`rtol`
for comparisons. Chronology changes also need horizon/interval/resolution,
initial-state, producer/consumer, and optional-emulator checks. Do not claim MPI
(Message Passing Interface) equivalence: its execution path is incomplete.

## Formatting

The repository's formatter command, run from the root, is:

```powershell
julia -e 'include(joinpath("scripts", "formatter", "formatter_code.jl"))'
```

It activates its own JuliaFormatter environment and formats the **whole
repository**, including Markdown. Inspect the diff and never discard unrelated
user changes. For documentation-only edits, use a targeted `format` invocation
with the options in that script rather than inadvertently reformatting all
computational source. Follow `.editorconfig` and the [style guide](style.md).

Run `git diff --check` for whitespace errors. Record exact validation commands,
outcomes, resolved dependency versions, and remaining blockers in the pull
request, following `CONTRIBUTING.md` and the PR template.
