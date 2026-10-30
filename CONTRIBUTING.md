# Contributing

Community contributions are welcome.

 1. Discuss modeling changes or report a reproducible bug in
    [an issue](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/issues).
    Include Julia/package versions, subsystem assignments, formulation names,
    chronology, and relevant logs, without confidential system data.
 2. Fork the repository and create a branch from `main`. Preserve computational
    compatibility with the released dependency targets in `Project.toml`,
    particularly PowerSimulations 0.38.5 or a compatible patch release. Do not
    substitute unreleased dependency checkouts simply to match newer documentation.
 3. Follow the [local style guide](docs/src/developer/style.md) and
    [development workflow](docs/src/developer/workflow.md). Add behavior-focused
    regression tests and update the affected documentation.
 4. Run the relevant checks and report their exact commands and results, including
    missing test dependencies or other blockers.
 5. Submit a pull request against `main` using the
    [pull request template](.github/pull_request_template.md). Explain physical
    assumptions, numerical tolerances, and any changes in supported behavior.

The previous contribution instructions referenced a
[legacy CLA service](https://www.clahub.com/agreements/NREL/PowerSimulationsDecomposition.jl).
That endpoint could not be verified. Ask the maintainers in your issue or pull
request for the current contributor-agreement process before merging; do not
assume that a broken endpoint waives an agreement requirement.
