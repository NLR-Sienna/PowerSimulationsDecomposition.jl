# PowerSimulationsDecomposition.jl

[![Main - CI](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/actions/workflows/main-tests.yml/badge.svg?branch=main)](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/actions/workflows/main-tests.yml)
[![codecov](https://codecov.io/gh/NLR-Sienna/PowerSimulationsDecomposition.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/NLR-Sienna/PowerSimulationsDecomposition.jl)
[![Documentation](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/actions/workflows/docs.yml/badge.svg)](https://nlr-sienna.github.io/PowerSimulationsDecomposition.jl/dev/)
[![Community](https://img.shields.io/badge/community-Sienna-sienna.svg?logo=github)](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/issues)
[![Downloads](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Ftotal_downloads%2FPowerSimulationsDecomposition&query=total_requests&label=Downloads)](https://juliapkgstats.com/api/v1/total_downloads/PowerSimulationsDecomposition)

`PowerSimulationsDecomposition.jl` extends
[PowerSimulations.jl](https://github.com/Sienna-Platform/PowerSimulations.jl)
with subsystem-filtered, multi-region optimization models for power-system
operations research. [PowerSystems.jl](https://github.com/Sienna-Platform/PowerSystems.jl)
owns system data and named subsystem membership; PowerSimulations owns the modeling,
simulation, chronology, and result interfaces.

## Functionality and limits

- Define a `MultiProblemTemplate` and build a `DecisionModel(MultiRegionProblem, ...)`
  containing one optimization container per named subsystem.
- Model split-area PTDF balances with state-estimation injections and optional
  monitored-line state-estimation flows.
- Execute regional solves sequentially and expose aggregated results through
  PowerSimulations.
- Pass state between full-system and regional stages, or between successive regional
  executions, with an optional full-system emulator.

This is research software, **not an automatic partitioner or an iterative
convergence algorithm**. The MPI (Message Passing Interface) execution path is
incomplete. MPI is a standard for communication between processes in parallel
programs; its presence here does not imply supported parallel execution.
Modeled HVDC terminal
buses must belong to the same subsystem. Overlapping result axes can overwrite
regional entries. Sparse contingency results preserve actual tuple keys;
reserve-deliverability regressions cover explicit monitoring in 10-bus and RTS cases.
See [supported behavior and limitations](docs/src/api/support.md).

## Installation

Use Julia **1.10 or newer**. The dependency upgrade targets PowerSimulations
0.38.4, PowerSystems 5.12.3, PowerNetworkMatrices 0.24.4, and InfrastructureSystems
3.6.3 or compatible releases allowed by `Project.toml`. Do not substitute
unreleased dependency checkouts. Declared version bounds do not by themselves
establish runtime compatibility; run the test suite when upgrading.


For a source checkout:

```powershell
git clone https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git
Set-Location PowerSimulationsDecomposition.jl
julia --project=. -e 'using Pkg; Pkg.instantiate(); using PowerSimulationsDecomposition'
```

From an existing Julia environment, install from the repository:

```julia
using Pkg
Pkg.add(url="https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git")
using PowerSimulationsDecomposition
```

These commands use the default branch. When working on a particular branch,
check it out before instantiating.

## Usage and documentation

Start with the [setup guide](docs/src/quick_start_guide.md) and the
[runnable two-region tutorial](docs/src/tutorials/intro_page.md). The tutorial uses
HiGHS and a small PowerSystemCaseBuilder fixture; both are declared in the docs
environment.

```powershell
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs\examples\decomposition.jl
```

- [User manual](https://nlr-sienna.github.io/PowerSimulationsDecomposition.jl/dev/):
  tutorials, how-to guides, and explanations.
- [Security-constrained reserves](docs/src/how_to/security_constrained_reserves.md):
  outage specifications, explicit monitoring, and a runnable regional example.
- [Formulation library](docs/src/formulation_library/network.md): the mathematical
  contracts owned by this package.
- [Public API](docs/src/api/public.md) and [internal extensions](docs/src/api/internal.md).
- [Developer guide](docs/src/developer/index.md): architecture, tests, and local docs builds.

Documentation is published on
[GitHub Pages](https://nlr-sienna.github.io/PowerSimulationsDecomposition.jl/dev/).
To build it locally, see the [developer workflow](docs/src/developer/workflow.md).

## Development

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution
procedures and use [repository issues](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/issues)
for questions and bug reports. The default branch is `main`.

## License

PowerSimulationsDecomposition.jl is released under the [BSD 3-Clause license](LICENSE).
Development includes work on Interregional Transmission Operational Coordination
(IRTOC), under GDO 20.

[National Laboratory of the Rockies (NLR)](https://www.nlr.gov/).
Historical copyright and legal attribution are retained in the license.
