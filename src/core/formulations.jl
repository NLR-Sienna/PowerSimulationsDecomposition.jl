# Formulations

"""
    SplitAreaPTDFPowerModel

Model subsystem-filtered area balances with PTDF network context.

Local injections enter area and nodal expressions. Internal state-estimation
parameters supply nonregional nodal injections in system-base per-unit quantities.
Optional area-interchange flows enter the from-area balance negatively and the
to-area balance positively. Configure this formulation through `PSI.NetworkModel`.
Subsystem membership must be supplied explicitly.
"""
struct SplitAreaPTDFPowerModel <: PSI.AbstractPTDFModel end

"""
    StaticBranchUnboundedStateEstimation

Reconstruct monitored-line PTDF flows from baseline flows and injection changes.

The concrete construction methods support `PSY.MonitoredLine` with a PSI PTDF
network model. Baseline parameters use system-base per-unit quantities. This
unbounded formulation does not add branch-rating inequalities; feedforward
constraints are attached through PSI.
"""
struct StaticBranchUnboundedStateEstimation <: PSI.AbstractBranchFormulation end
