# Reusable contributor CI entry point. Exercise the same real package-entry
# refusal probes as the package suite, in fresh processes without numerical deps.
include(joinpath(@__DIR__, "compatibility_tests.jl"))
