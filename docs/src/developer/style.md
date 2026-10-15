# Style guide

Follow existing repository conventions and the
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).
For docstrings, use the
[JuMP docstring conventions](https://jump.dev/JuMP.jl/stable/developers/style/#Docstrings).
The repository-specific rules below complement those references.

## Julia

  - Use four spaces, LF endings, final newlines, and no trailing whitespace.
  - Use `snake_case` functions, `CamelCase` types, and `!` for mutation where
    consistent with the extended PSI interface.
  - Preserve PSI dispatch specificity, signatures, include order, and aliases.
    Explicitly type new arguments with the least restrictive meaningful types;
    do not narrow upstream generic forwarding solely for style.
  - Reuse shared helpers and multiple dispatch rather than duplicated branching.
    Keep construction, state transfer, validation, and I/O responsibilities clear.
  - Preserve error context. Use explicit repository-standard errors/logging rather
    than broad catches, silent defaults, or success-shaped failure returns.
  - Keep hot paths inferable; investigate type instability with the concrete
    specialization rather than hiding it with casts or arbitrary conversions.
  - Preserve physical units, branch signs, bus mappings, service metadata, and
    forecast chronology. Modeling policy changes require explicit justification.

## Documentation

  - Start docstrings with an indented signature and an imperative summary.
  - Explain actual inputs, mutation, outputs, units, axes, errors, and limitations;
    avoid mechanically adding empty headings.
  - Use local `@ref` links only for documented bindings. Link external APIs to
    their owning package/version instead of inventing local references.
  - Keep tutorials runnable with declared prerequisites. Test helpers must never
    appear as exported package APIs.
  - Separate tutorials, task-oriented how-tos, conceptual explanations,
    formulation contracts, and API reference.
  - Trace diagrams and equations to source/tests. Do not invent convergence,
    optimality, resampling, or formulation-support guarantees.
  - Preserve historical attribution and legal text when updating present-day
    institutional terminology.

See [Workflow and validation](workflow.md) for the actual formatter and test
commands; do not substitute a nonexistent style-guide path or generic tooling.
