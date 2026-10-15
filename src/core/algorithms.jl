"""
    DecompositionAlgorithm

Identify the internal dispatch family for regional container algorithms.
"""
abstract type DecompositionAlgorithm end

"""
    SequentialAlgorithm

Build regional containers and solve each once per model execution.

Iteration follows the subproblem dictionary. This internal algorithm aggregates
results only after all regional solves succeed; it has no convergence loop.
"""
struct SequentialAlgorithm <: DecompositionAlgorithm end
"""
    MPIParallelAlgorithm

Identify the incomplete internal MPI (Message Passing Interface) execution scaffold.

The solve method contains unresolved names and does not provide a supported
parallel execution path.
"""
struct MPIParallelAlgorithm <: DecompositionAlgorithm end
