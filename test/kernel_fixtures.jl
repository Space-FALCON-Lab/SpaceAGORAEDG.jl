# Fixtures for the kernel regression tests. These tests moved here from SpaceAGORA,
# which kept only its two decision routes; they check the same values as before.

const EDG = SpaceAGORAEDG

# A test-only route to one kernel through SpaceAGORA's real invoker, the one that
# carries the decision `guidance_decision!`. The core projects the arguments as
# for a decision: its parameters become a borrowed prediction context that expires
# when the call returns, also after an exception; a spacecraft or a planet becomes
# copied values; an observation and other arrays are copied. When the kernel needs
# the control clock, the EDG run state goes first and the probe drops it. This
# method is defined only in the test process; the package defines no probe.
struct KernelProbe
    kernel::Function
    drop_state::Bool
end
function SpaceAGORAEDG.guidance_decision!(probe::KernelProbe, args...; kwargs...)
    return probe.drop_state ? probe.kernel(Base.tail(args)...; kwargs...) : probe.kernel(args...; kwargs...)
end
# `probe(f, args...)` calls `f` with the projected arguments; `clocked_probe(f, state, args...)`
# also gives the prediction context the control clock of `state`.
probe(f, args...; kwargs...) = S.guidance_decision!(KernelProbe(f, false), args...; kwargs...)
clocked_probe(f, state::AerobrakingEnergyDepletionState, args...; kwargs...) =
    S.guidance_decision!(KernelProbe(f, true), state, args...; kwargs...)
# `K._edg_x(args...)` and `KC._edg_x(state, args...)` call the package's kernel `_edg_x`.
struct Kernels
    clocked::Bool
end
Base.getproperty(kernels::Kernels, name::Symbol) = (args...; kwargs...) ->
    (getfield(kernels, :clocked) ? clocked_probe : probe)(getglobal(SpaceAGORAEDG, name), args...; kwargs...)
const K = Kernels(false)
const KC = Kernels(true)

# The context below is copied from SpaceAGORA's test/gnc/aerobraking/energy_depletion_gnc_tests.jl
# at v0.6.0 (0487e8226), with two changes: it uses SpaceAGORA's exported names where
# there are some, and the observation is a named tuple, not a ComponentVector, which
# this package's tests do not load; it holds the same values. The private SpaceAGORA
# names these tests still use are `SM` below: `Mars`, `Venus`, `ODEParams` with its
# `args` and `shared_buffers` fields, and `SimConfig._with_configuration`.
const SM = SpaceAGORA.SimulationModel
const _ODYSSEY_LIMIT_QDOT_W_CM2 = 0.15
const _ODYSSEY_LIMIT_Q_J_CM2 = 30.0
const _ODYSSEY_LIMIT_DYN_PRESS_PA = 0.5
const _ODYSSEY_RA_INITIAL_M = 9_800e3
const _ODYSSEY_HP_INITIAL_M = 100e3
const _ODYSSEY_EPOCH = (year=2001, month=11, day=6, hour=19, minute=0, second=0.0)
const _VEX_HP_INITIAL_M = 136e3
const _VEX_TARGET_RA_M = 72_480e3

function _edg_test_context(;
    guidance_modes=(:max_energy_depletion,),
    max_energy_submodes=(:heat_rate, :structural_load, :heat_load),
    heat_load_switch_solver=:closed_form,
    target_apoapsis_radius_m=4.84e6,
    heat_rate_limit_w_cm2=_ODYSSEY_LIMIT_QDOT_W_CM2,
    heat_load_limit_j_cm2=1e-4,
    structural_load_limit_pa=_ODYSSEY_LIMIT_DYN_PRESS_PA,
    density_reference_kg_m3=1e-4,
    gravity_models=(InverseSquaredGravityModel(),),
    density_model=ExponentialAtmosphereModel(density_reference_kg_m3, 100e3, 20e3; temperature_k=150.0),
    planning_horizon_s=5_000.0,
    heat_load_security_mode=true,
)
    planet = SM.Mars()
    planet.L_PI .= @SMatrix [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
    rp = planet.Rp_e + _ODYSSEY_HP_INITIAL_M
    semi_major = 0.5 * (_ODYSSEY_RA_INITIAL_M + rp)
    periapsis_speed = sqrt(planet.μ * (2.0 / rp - 1.0 / semi_major))
    pos = SVector{3, Float64}(rp, 0.0, 0.0)
    vel = SVector{3, Float64}(0.0, periapsis_speed, 0.0)
    ic = CartesianInitialCondition(pos, vel)

    root = Link(
        root=true,
        m=391.0,
        dims=MVector{3, Float64}(2.2, 2.6, 1.7),
        ref_area=2.2 * 1.7,
        reflection_coefficient=0.9,
    )
    left = Link(
        root=false,
        m=10.0,
        dims=MVector{3, Float64}(0.01, 3.76 / 2.0, 1.93),
        ref_area=(3.76 / 2.0) * 1.93,
        r=MVector{3, Float64}(0.0, -2.0, 0.0),
        reflection_coefficient=0.9,
    )
    right = Link(
        root=false,
        m=10.0,
        dims=MVector{3, Float64}(0.01, 3.76 / 2.0, 1.93),
        ref_area=(3.76 / 2.0) * 1.93,
        r=MVector{3, Float64}(0.0, 2.0, 0.0),
        reflection_coefficient=0.9,
    )
    spacecraft = SpacecraftModel(
        Joint[],
        [root, left, right],
        root,
        true,
        411.0,
        50.0,
        root.inertia,
        0,
        0,
        ic,
        1,
    )

    state = AerobrakingEnergyDepletionState(num_sats=1)
    # A run reports the EDG control clock when it starts; direct calls here use the
    # configured 1 s control period from the origin.
    state.control_clock_period_s = 1.0
    config = AerobrakingEnergyDepletionConfig(
        guidance_modes=guidance_modes,
        max_energy_submodes=max_energy_submodes,
        heat_load_switch_solver=heat_load_switch_solver,
        controlled_panel_links=(2, 3),
        target_apoapsis_radius_m=target_apoapsis_radius_m,
        max_alpha_rad=pi / 2,
        min_alpha_rad=1e-4,
        heat_rate_limit_w_cm2=heat_rate_limit_w_cm2,
        heat_load_limit_j_cm2=heat_load_limit_j_cm2,
        structural_load_limit_pa=structural_load_limit_pa,
        planning_horizon_s=planning_horizon_s,
        heat_load_security_mode=heat_load_security_mode,
        switch_recompute_interval_s=1.0,
    )
    guidance = AerobrakingEnergyDepletionGuidanceModel(config, state)
    control = AerobrakingEnergyDepletionControlModel(config, state)
    args = SimulationConfiguration(
        environment_model=EnvironmentModel(
            planet=planet,
            EI=160.0,
            density_model=density_model,
            ephemerides_model=SimpleEphemeridesModel(),
            topography=false,
            topo_degree=0,
            topo_order=0,
            wind=false,
            thermal_model=MaxwellianHeat(thermal_accomodation_factor=1.0, planet=planet),
        ),
        dynamics_model=DynamicsModel([spacecraft], gravity_models),
        guidance_model=GuidanceModel((guidance,), [1.0]),
        navigation_model=NavigationModel((), Float64[]),
        control_model=ControlModel((control,), [1.0]),
        initial_time=InitialTime(
            year=_ODYSSEY_EPOCH.year,
            month=_ODYSSEY_EPOCH.month,
            day=_ODYSSEY_EPOCH.day,
            hour=_ODYSSEY_EPOCH.hour,
            minute=_ODYSSEY_EPOCH.minute,
            second=_ODYSSEY_EPOCH.second,
        ),
    )
    p = SM.ODEParams(n_sats=1, args=args)
    p.shared_buffers.et_start[] = ephemerides_epoch_seconds(args.environment_model.ephemerides_model, args.initial_time)
    u = (sc=[(pos=collect(pos), vel=collect(vel), mass=461.0, heat_loads=zeros(3))],)
    return (; config, state, guidance, control, args, p, u, spacecraft)
end

state_values(s) = Tuple(copy(getfield(s, f)) for f in fieldnames(typeof(s)))
