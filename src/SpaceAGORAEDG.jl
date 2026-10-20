"""Experimental energy-depletion guidance through SpaceAGORA's versioned services."""
module SpaceAGORAEDG
import SpaceAGORA
const REQUIRED_CONTRACT_VERSION = v"2.0.0"
isdefined(SpaceAGORA, :EDGServices) || error("SpaceAGORAEDG requires a SpaceAGORA build with EDGServices. Install the documented exact package pair and start a fresh process.")
SpaceAGORA.EDGServices.require_version(REQUIRED_CONTRACT_VERSION)
using LinearAlgebra, StaticArrays, Roots, SpecialFunctions, NLsolve
using SpaceAGORA.EDGServices: AbstractPredictionContext,
    EDGControlDecision,
    AerobrakingEnergyDepletionConfig,
    AerobrakingEnergyDepletionState,
    AerobrakingControlCommand,
    planet_constants,
    thermal_parameters,
    entry_altitude_m,
    spacecraft_geometry,
    density_scale_height,
    frame_state,
    gravity_acceleration,
    _edg_control_sat_state,
    _edg_control_pos_vel_mass,
    _edg_environment_state,
    _edg_in_drag_passage,
    _edg_ephemeris_time,
    _edg_targeting_prediction_environment,
    _edg_targeting_control_clock,
    aerodynamic_coefficient_fM,
    rvtoorbitalelement,
    rtolatlong
function require_version(expected::VersionNumber)
    expected == REQUIRED_CONTRACT_VERSION || throw(SpaceAGORA.EDGServices.CompatibilityError(
        "This SpaceAGORAEDG implementation requires EDG contract $REQUIRED_CONTRACT_VERSION, not $expected."))
    SpaceAGORA.EDGServices.require_version(expected)
    return nothing
end
function __init__()
    require_version(REQUIRED_CONTRACT_VERSION)
end

include("heat_rate.jl")
include("heat_load.jl")
include("structural_load.jl")
include("targeting.jl")
include("targeting_plan.jl")
include("pass_heat.jl")
include("guidance_decision.jl")
include("angle_decision.jl")

end # module SpaceAGORAEDG
