# Validate paths and the retained private fixture without loading native code,
# furnishing SPICE kernels, creating outputs or advancing a simulation.
include(joinpath(@__DIR__, "paths.jl"))
NativeReferencePaths.preflight()
