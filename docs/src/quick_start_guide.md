# Getting started

## Prerequisites

  - Use Julia **1.10+**; the documentation workflow tracks the latest stable
    Julia 1.x release using `setup-julia`'s `version: '1'` selector.
    The root project and the released Sienna dependency targets require Julia 1.10.
  - Know PowerSystems components, named subsystems, deterministic forecasts, and
    PowerSimulations device/network templates.
  - Select a solver that supports your formulations. The tutorial uses HiGHS;
    unit commitment additionally requires mixed-integer support.
  - Allow network access for Julia packages, solver artifacts, and the tutorial's
    PowerSystemCaseBuilder fixture on first use.

The dependency upgrade targets in the root `Project.toml` are PowerSimulations
**0.38.4**, PowerSystems **5.12.3**, PowerNetworkMatrices **0.24.4**, and
InfrastructureSystems **3.6.3**, with compatible releases allowed by Julia's
compatibility rules. Do not develop the neighboring PSI `main` checkout into
this environment: its APIs and compatibility bounds can be newer. Always inspect
the resolved versions and run the tests; version bounds alone do not establish
runtime compatibility.

## Set up a checkout

Run these commands in PowerShell:

```powershell
git clone https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git
Set-Location PowerSimulationsDecomposition.jl
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.status(); using PowerSimulationsDecomposition'
```

To install into another Julia project rather than work on a checkout:

```julia
using Pkg
Pkg.add(url="https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git")
using PowerSimulationsDecomposition
```

No claim about registration is required by the URL-based installation.

## Run the tutorial

From the repository root:

```powershell
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); Pkg.status()'
julia --project=docs docs\examples\decomposition.jl
```

The docs environment declares the local package, PowerSimulations, PowerSystems,
PowerSystemCaseBuilder, and HiGHS. The script asserts successful build and solve,
then checks result coverage, finite dispatch, and nonnegative dispatch within a
numerical tolerance. It writes model/results files to a temporary directory.
Read the [tutorial](tutorials/intro_page.md) before adapting its deliberately
simple regional assumptions to your system.

If package resolution fails, check the selected Julia version and whether a
developed dependency overrides the declared compatibility range. Do not solve
resolution failures by upgrading the computational dependency bounds.

## Next steps

Assign every relevant component explicitly with the
[subsystem guide](how_to/subsystems.md), then choose a chronology using
[state passing](explanation/state_passing.md). Check
[limitations](api/support.md) before interpreting aggregated results.
