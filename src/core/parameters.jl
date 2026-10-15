"""
    StateEstimationInjections

Identify internal baseline nodal-injection parameters on `PSY.ACBus`.

Values initialize to zero with unit multipliers and use bus-number strings and
time indices. Simulation updates read `ActivePowerBalance` expression state in
system-base per-unit quantities. No general resampling contract is implemented.
"""
struct StateEstimationInjections <: PSI.VariableValueParameter end
"""
    StateEstimationFlows

Identify internal baseline flow parameters on `PSY.MonitoredLine`.

Values initialize to zero with unit multipliers and use branch names and time
indices. Simulation updates read `PTDFBranchFlow` expression state in system-base
per-unit quantities.
"""
struct StateEstimationFlows <: PSI.VariableValueParameter end
