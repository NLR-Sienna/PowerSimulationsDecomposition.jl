"""
    NetworkFlowConstraintStateEstimation

Identify the equality registered for state-estimation PTDF flow expressions.

Use this PSI constraint key with [`StaticBranchUnboundedStateEstimation`](@ref).
The flow builder mutates the registered expression store before constructing the
equality. This key does not identify a thermal branch-rating inequality.
"""
struct NetworkFlowConstraintStateEstimation <: PSI.ConstraintType end
