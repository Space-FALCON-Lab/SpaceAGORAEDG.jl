# Targeting kernels: target energy, prediction clock and events, switch
# certificates and candidate maps. Each testset carries the name of the
# SpaceAGORA testset its assertions came from.

@testset "VEX N-body target-energy correction" begin
    # Venus's built-in constants: this package's test environments carry no SPICE
    # kernels. The identity does not depend on the planet's constants.
    planet = SM.Venus()
    periapsis_radius = planet.Rp_e + _VEX_HP_INITIAL_M
    nominal_target = K._edg_target_energy_from_apoapsis(
        planet,
        _VEX_TARGET_RA_M,
        periapsis_radius,
    )
    @test K._edg_corrected_target_energy_from_apoapsis(
        planet,
        _VEX_TARGET_RA_M,
        periapsis_radius,
        125.0,
    ) == nominal_target - 125.0
end

@testset "Energy depletion GNC config and guidance" begin
    ctx_targeting = _edg_test_context(density_reference_kg_m3=1e-7, guidance_modes=(:targeting, :max_energy_depletion))
    update_guidance!(ctx_targeting.guidance, ctx_targeting.u, ctx_targeting.p, 0.0, 1)
    sc = ctx_targeting.u.sc[1]
    pos = SVector{3, Float64}(sc.pos)
    vel = SVector{3, Float64}(sc.vel)
    low_drag, max_energy = KC._edg_targeting_bracket_outcomes(ctx_targeting.state,
        ctx_targeting.config,
        ctx_targeting.p,
        ctx_targeting.spacecraft,
        pos,
        vel,
        Float64(sc.mass),
        0.0;
        heat_load_j_cm2=0.0,
        heat_rate_control=true,
        structural_control=true,
    )
    @test ctx_targeting.state.bracket_max_energy_jkg[1] ≈ low_drag.energy_jkg
    @test all(isfinite, max_energy.heat_load_switches_s)
    @test max_energy.heat_load_switches_s[1] < max_energy.heat_load_switches_s[2]
end

@testset "EDG Phase 2 and 3 scheduling parity" begin
    ctx_before_targeting = _edg_test_context(
        guidance_modes=(:targeting, :max_energy_depletion),
    )
    planet = ctx_before_targeting.args.environment_model.planet
    ctx_before_targeting.u.sc[1].pos .= (planet.Rp_e + 300e3, 0.0, 0.0)
    update_guidance!(ctx_before_targeting.guidance, ctx_before_targeting.u, ctx_before_targeting.p, 0.0, 1)

    targeting_grid = K._edg_targeting_prediction_time_grid(10.4)
    @test first(targeting_grid) == 0.0
    @test last(targeting_grid) == 10.4
    @test maximum(diff(targeting_grid)) <= 1.0

    fit = K._edg_closed_form_correction_fit(planet)
    @test fit[1:4] == (4350.0, 450.0, -5.25, 2.25)
    @test fit[5] == (4.560850, -1.715925, -0.375150, 0.376025, -0.254500)
    @test fit[6][1:4] == (-4.74628450, -3.69824500, -6.06348525, 1.07688200)

    rp = planet.Rp_e + _ODYSSEY_HP_INITIAL_M
    a = 0.5 * (_ODYSSEY_RA_INITIAL_M + rp)
    e = 1.0 - rp / a
    interface_radius = planet.Rp_e + 160e3
    nu_exit = acos((a * (1.0 - e^2) / interface_radius - 1.0) / e)
    nu_outbound = 0.5 * nu_exit
    semi_latus_rectum = a * (1.0 - e^2)
    radius_outbound = semi_latus_rectum / (1.0 + e * cos(nu_outbound))
    pos_outbound = SVector{3, Float64}(
        radius_outbound * cos(nu_outbound),
        radius_outbound * sin(nu_outbound),
        0.0,
    )
    velocity_scale = sqrt(planet.μ / semi_latus_rectum)
    vel_outbound = velocity_scale * SVector{3, Float64}(-sin(nu_outbound), e + cos(nu_outbound), 0.0)
    outbound_duration = K._edg_drag_passage_duration(
        ctx_before_targeting.config,
        ctx_before_targeting.p,
        pos_outbound,
        vel_outbound,
        461.0,
    )
    expected_duration = (
        K._edg_mean_anomaly_from_true(nu_exit, e) -
        K._edg_mean_anomaly_from_true(nu_outbound, e)
    ) / sqrt(planet.μ / a^3)
    @test outbound_duration ≈ expected_duration rtol=1e-10
    @test outbound_duration < 1_000.0
end

@testset "EDG sampled prediction clock and exact events" begin
    period = 1 / 3
    for (t, origin) in ((0.0,0.0), (0.1,0.0), (10/3,0.0), (12.345,12.345), (12.445,12.345))
        grid = K._edg_targeting_prediction_time_grid(2.07; t0=t, period=period, origin=origin)
        @test first(grid) == 0.0
        @test last(grid) == 2.07
        @test all(diff(grid) .> 0.0)
        @test maximum(diff(grid)) <= period + 1e-12
        @test all(isapprox((t + x - origin) / period, round((t + x - origin) / period); atol=1e-12) for x in grid[2:end-1])
    end
    @test K._edg_switch_due(143.33333333333331,143.33333333333334)
    @test !K._edg_switch_due(143.0,143.33333333333334)
    @test !K._edg_switch_due(1.0,Inf)
    @test_throws ArgumentError K._edg_targeting_prediction_time_grid(1.0; period=0.0)
    @test_throws ArgumentError K._edg_targeting_prediction_time_grid(Inf)

    ctx = _edg_test_context(max_energy_submodes=(:heat_rate,),heat_rate_limit_w_cm2=Inf)
    ctx.state.control_clock_period_s = period
    ctx.state.control_clock_origin_s = 0.1
    clock = clocked_probe(S._edg_targeting_control_clock, ctx.state, ctx.p)
    @test clock == (period=period,origin=0.1)
    for link in ctx.spacecraft.links[2:3]; link.α = 0.37; end
    t = 0.2
    grid = K._edg_targeting_prediction_time_grid(1.0;t0=t,period=period,origin=clock.origin)
    R=SVector{3,Float64}(ctx.u.sc[1].pos); V=SVector{3,Float64}(ctx.u.sc[1].vel)
    track=KC._edg_integrated_targeting_trajectory(ctx.state,ctx.config,ctx.p,ctx.spacecraft,R,V,461.0,t,grid,t;
        heat_rate_control=false,structural_control=false)
    @test track.alpha_profile[1] == 0.37
    @test all(track.alpha_profile[2:end-1] .== ctx.config.min_alpha_rad)
    @test_throws ErrorException K._edg_exact_targeting_exit(ctx.config,ctx.p,ctx.spacecraft,461.0,t,track)
    ctx.state.control_clock_period_s=0.0
    @test_throws ArgumentError clocked_probe(S._edg_targeting_control_clock, ctx.state, ctx.p)
    # Before its run starts the clock has no period, and a call without an EDG
    # state has no clock at all; neither is read from the configuration.
    ctx.state.control_clock_period_s=NaN
    @test_throws ArgumentError clocked_probe(S._edg_targeting_control_clock, ctx.state, ctx.p)
    @test_throws ArgumentError probe(S._edg_targeting_control_clock, ctx.p)

    # A known crossing inside a coarse interval must not return its endpoint.
    r=SVector(0.0,0.0,0.0);v=SVector(1.0,0.0,0.0)
    a(r,v,t)=SVector(0.0,0.0,0.0)
    re,ve,te=K._edg_prediction_event(a,(r,v,t)->r[1]-2.3,r,v,0.0,10.0)
    @test te ≈ 2.3 atol=1e-8
    @test re[1] ≈ 2.3 atol=1e-8
    @test ve == v
    # A ten-second held command still integrates with the one-second cap.
    oscillator(r,v,t)=-r
    slow_r,slow_v=K._edg_prediction_advance(oscillator,SVector(1.0,0.0,0.0),zero(v),0.0,10.0)
    @test abs(slow_r[1]-cos(10.0)) < 0.1
    @test abs(slow_v[1]+sin(10.0)) < 0.1
end

@testset "EDG refuses a dense passage without an outbound interface" begin
    c = _edg_test_context()
    sc = c.u.sc[1]
    @test_throws ErrorException KC._edg_predict_targeting_outcome(c.state,
        c.config,c.p,c.spacecraft,SVector{3,Float64}(sc.pos),SVector{3,Float64}(sc.vel),
        Float64(sc.mass),0.0,0.0;heat_rate_control=true,structural_control=true)
end

@testset "EDG exit direction and evaluated switch certificate" begin
    c = _edg_test_context(density_reference_kg_m3=1e-7)
    mass = Float64(c.u.sc[1].mass)
    planet = c.args.environment_model.planet
    r = SVector{3,Float64}(planet.Rp_e+160e3,0,0)
    v = SVector{3,Float64}(1,4000,0)
    track = (h=[160e3],positions=[r],velocities=[v],time=[0.0],alpha_profile=[0.0])
    ex = K._edg_exact_targeting_exit(c.config,c.p,c.spacecraft,mass,0.0,track)
    @test ex.time == 0.0
    @test ex.position == r
    @test_throws ErrorException K._edg_exact_targeting_exit(c.config,c.p,c.spacecraft,mass,0.0,
        merge(track,(velocities=[SVector{3,Float64}(-1,4000,0)],)))
    @test_throws ErrorException K._edg_exact_targeting_exit(c.config,c.p,c.spacecraft,mass,0.0,
        merge(track,(h=[160e3+1.0],)))
    pos = SVector{3,Float64}(c.u.sc[1].pos)
    vel = SVector{3,Float64}(c.u.sc[1].vel)
    c.state.control_clock_origin_s = 0.125
    for t in (0.125,0.225)
        first_tick = t == 0.125 ? t : 1.125
        last_tick = 2000.125
        outcome(sw) = KC._edg_predict_targeting_outcome(c.state,c.config,c.p,c.spacecraft,pos,vel,mass,t,sw;
            heat_rate_control=true,structural_control=true)
        c.state.target_energy_jkg[1] = (outcome(first_tick).energy_jkg+outcome(last_tick).energy_jkg)/2
        cert = K._edg_targeting_switch_solution(c.config,c.state,c.p,c.spacecraft,pos,vel,mass,t,1;
            heat_rate_control=true,structural_control=true)
        @test cert.left_switch_s >= t
        @test cert.right_switch_s <= t+2000
        @test cert.right_switch_s-cert.left_switch_s <= 1.0+1e-12
        @test K._edg_at_control_tick(cert.switch_s,1.0,0.125)
        @test signbit(cert.left_residual_jkg) != signbit(cert.right_residual_jkg) || iszero(cert.residual_jkg)
        @test abs(cert.residual_jkg) <= min(abs(cert.left_residual_jkg),abs(cert.right_residual_jkg))
        predicted = outcome(cert.switch_s)
        @test predicted.energy_jkg-c.state.target_energy_jkg[1] ≈ cert.residual_jkg atol=1e-8
        env = probe(S._edg_targeting_prediction_environment,c.p,predicted.exit_position,predicted.exit_velocity,t+predicted.duration_s)
        @test abs(env.altitude_m-160e3) < 1e-5
    end
end

@testset "EDG-T candidate-map certification" begin
    candidate_times = [0.0, 1.0, 2.0, 3.0]

    ordered_energy = [10.0, 9.0, 8.0, 7.0]
    feasible_heat = [1.0, 2.0, 3.0, 4.0]
    ordered_evaluator(t) = begin
        idx = round(Int, t) + 1
        (energy_jkg=ordered_energy[idx], heat_load_j_cm2=feasible_heat[idx])
    end
    ordered = K._edg_certify_targeting_candidates(
        candidate_times,
        ordered_evaluator;
        heat_load_limit_j_cm2=5.0,
        energy_order_tolerance_jkg=1e-6,
        heat_load_tolerance_j_cm2=1e-6,
    )
    @test ordered.times == candidate_times
    @test ordered.failure == :none

    nonmonotone_energy = [10.0, 9.0, 9.5, 8.0]
    nonmonotone_evaluator(t) = begin
        idx = round(Int, t) + 1
        (energy_jkg=nonmonotone_energy[idx], heat_load_j_cm2=feasible_heat[idx])
    end
    nonmonotone = K._edg_certify_targeting_candidates(
        candidate_times,
        nonmonotone_evaluator;
        heat_load_limit_j_cm2=5.0,
        energy_order_tolerance_jkg=1e-6,
        heat_load_tolerance_j_cm2=1e-6,
    )
    @test nonmonotone.times == candidate_times[1:2]
    @test nonmonotone.failure == :energy_order
    @test nonmonotone.failure_time_s == candidate_times[3]

    infeasible_heat = [1.0, 2.0, 6.0, 4.0]
    heat_evaluator(t) = begin
        idx = round(Int, t) + 1
        (energy_jkg=ordered_energy[idx], heat_load_j_cm2=infeasible_heat[idx])
    end
    heat_limited = K._edg_certify_targeting_candidates(
        candidate_times,
        heat_evaluator;
        heat_load_limit_j_cm2=5.0,
        energy_order_tolerance_jkg=1e-6,
        heat_load_tolerance_j_cm2=1e-6,
    )
    @test heat_limited.times == candidate_times[1:2]
    @test heat_limited.failure == :heat_load
    @test heat_limited.failure_time_s == candidate_times[3]
end

# A density model and an ephemerides model that record each query, copied from
# SpaceAGORA's test/gnc/aerobraking/energy_depletion_ownership_tests.jl at v0.6.0.
mutable struct QueryDensity <: AbstractDensityModel
    events::Vector{Any}
    fail::Bool
end
function SpaceAGORA.getDensity(m::QueryDensity,h::Float64,lat::Float64,lon::Float64,t::Float64,wind::Bool,p)
    push!(m.events,(:density,h,lat,lon,t,wind))
    m.fail && throw(ArgumentError("density witness"))
    return 1e-9,150.,SVector(60.,-35.,4.)
end
struct QueryFrames <: AbstractEphemeridesModel
    events::Vector{Any}
end
SpaceAGORA.ephemerides_requires_spice(::QueryFrames) = false
function SpaceAGORA.ephemerides_frame_lpi(m::QueryFrames, planet, t::Float64)
    push!(m.events,(:frame,t))
    return SMatrix{3,3,Float64}(I)
end
function spy_context(; kwargs...)
    events=Any[]; density=QueryDensity(events,false)
    x=_edg_test_context(; density_model=density,kwargs...)
    old=x.args.environment_model
    fields=(; (f=>getfield(old,f) for f in fieldnames(typeof(old)))...)
    env=EnvironmentModel(; merge(fields,(ephemerides_model=QueryFrames(events),wind=true))...)
    args=SM.SimConfig._with_configuration(x.args;environment_model=env)
    p=SM.ODEParams(n_sats=1,args=args);p.shared_buffers.et_start[]=12345.
    return (;x...,args,p,events,density)
end

@testset "Lazy projection, query coordinates, time, wind and failure order" begin
    x=spy_context(max_energy_submodes=(:heat_rate,),heat_rate_limit_w_cm2=Inf)
    # An evaluated bracket is not evaluated again: no query reaches the run.
    x.state.energy_bracketing_evaluated[1]=true
    K._edg_run_target_energy_bracketing!(x.config,x.state,x.u,x.p,7.,1)
    @test isempty(x.events)
end

@testset "Structured/flat inputs, missing mass and spacecraft index" begin
    x=_edg_test_context(max_energy_submodes=(:heat_rate,),heat_rate_limit_w_cm2=Inf)
    @test K._edg_predict_mass(x.spacecraft,NaN) == K._edg_predict_mass(x.spacecraft,Inf)
    @test K._edg_predict_mass(x.spacecraft,321.)==321.
end

# Three SpaceAGORA integration tests (the journal live replanning, the assembled
# replan callbacks and the AlgorithmGuidance replanning) start from targets these
# kernels give. SpaceAGORA records the values; this checks the kernels still give
# them. Recorded on SpaceAGORA v0.6.0 through its own kernel calls, on macOS.
# The comparison allows a relative 1e-12, not bit equality: the same code gives
# the apoapsis radius a few units in the last place apart on another platform
# (9.750451931596266e6 against 9.750451931596259e6 on Linux), while a kernel
# change that matters moves these values by far more (1e-12 of the apoapsis
# radius is about 10 micrometres).
const RECORDED_RTOL = 1e-12
const RECORDED_TARGETS = (
    # Control clock period 1 s: the journal's live replanning, which also starts
    # from the predicted energy and the predicted state 2 s into the passage.
    (period=1.0, target=9.750451931596259e6, energy=-3.2213806175077297e6,
        pos2=SVector(3.3890335691519254e6, 1.0467160974865406e6, 0.0),
        vel2=SVector(-850.7081980339041, 4121.059596430641, 0.0)),
    # Control clock period 1/3 s: the replan callbacks and AlgorithmGuidance.
    (period=1/3, target=9.750451931596396e6, energy=nothing, pos2=nothing, vel2=nothing),
)
@testset "Recorded targets of SpaceAGORA's targeting integration tests" begin
    for recorded in RECORDED_TARGETS
        c=_edg_test_context(guidance_modes=(:targeting,:max_energy_depletion),
            density_reference_kg_m3=1e-7,heat_load_limit_j_cm2=30.0,
            gravity_models=(InverseSquaredJ2GravityModel(),))
        if recorded.period != 1.0
            c.args.control_model.control_rates[1]=recorded.period
            c.state.control_clock_period_s=recorded.period
        end
        planet=c.args.environment_model.planet
        rp=planet.Rp_e+100e3; ra=_ODYSSEY_RA_INITIAL_M; a=(rp+ra)/2
        e=(ra-rp)/(ra+rp); sl=a*(1-e^2); radius=planet.Rp_e+150e3
        nu=acos((sl/radius-1)/e)
        r=SVector(radius*cos(nu),radius*sin(nu),0.0)
        v=sqrt(planet.μ/sl)*SVector(-sin(nu),e+cos(nu),0.0)
        known=KC._edg_predict_targeting_outcome(c.state,c.config,c.p,c.spacecraft,r,v,461.0,0.0,10.0;
            heat_rate_control=true,structural_control=true)
        coast=K._edg_vacuum_apoapsis_correction(c.p,known.exit_position,known.exit_velocity,
            461.0,known.duration_s)
        @test coast.event_reached
        @test isapprox(norm(coast.position), recorded.target; rtol=RECORDED_RTOL)
        recorded.energy === nothing && continue
        @test isapprox(known.energy_jkg, recorded.energy; rtol=RECORDED_RTOL)
        idx=findfirst(==(2.0),known.track.time)
        @test idx!==nothing
        @test isapprox(known.track.positions[idx], recorded.pos2; rtol=RECORDED_RTOL)
        @test isapprox(known.track.velocities[idx], recorded.vel2; rtol=RECORDED_RTOL)
    end
end

@testset "Both targeting strategies preserve sample results and clocks" begin
    c = _edg_test_context(max_energy_submodes=(:heat_rate,), heat_rate_limit_w_cm2=Inf)
    c.state.control_clock_period_s = 1 / 3
    c.state.control_clock_origin_s = 0.1
    for link in c.spacecraft.links[2:3]; link.α = 0.37; end
    t = 0.2
    times = K._edg_targeting_prediction_time_grid(1.07; t0=t, period=1/3, origin=0.1)
    pos = SVector{3,Float64}(c.u.sc[1].pos)
    vel = SVector{3,Float64}(c.u.sc[1].vel)
    for strategy in (:targeting, :max_energy)
        track = if strategy == :targeting
            KC._edg_integrated_targeting_trajectory(c.state, c.config, c.p, c.spacecraft,
                pos, vel, 461.0, t, times, t; heat_rate_control=false, structural_control=false)
        else
            KC._edg_integrated_max_energy_depletion_trajectory(c.state, c.config, c.p, c.spacecraft,
                pos, vel, 461.0, t, times, (Inf, Inf); heat_rate_control=false, structural_control=false)
        end
        @test keys(track) == (:time, :h, :gamma, :speed, :rho, :temperature,
            :speed_ratio, :positions, :velocities, :alpha_profile)
        @test track.time == times
        @test track.positions[1] == pos && track.velocities[1] == vel
        @test track.alpha_profile[1] == 0.37
        @test track.alpha_profile[end] == track.alpha_profile[end-1] # off the control clock
        expected_alpha = strategy == :targeting ? c.config.min_alpha_rad : c.config.max_alpha_rad
        @test all(track.alpha_profile[2:end-1] .== expected_alpha)
        @test all(length(getfield(track, field)) == length(times) for field in keys(track))
        for j in eachindex(times)
            env = probe(S._edg_targeting_prediction_environment, c.p,
                track.positions[j], track.velocities[j], t + times[j])
            @test track.h[j] == env.altitude_m
            @test track.speed[j] == env.speed
            @test track.rho[j] == env.rho
            @test track.temperature[j] == env.temperature
            @test track.speed_ratio[j] == env.molecular_speed_ratio
            # Independent geometric flight-path-angle check on the returned state.
            @test sin(track.gamma[j]) ≈ dot(normalize(track.positions[j]), normalize(track.velocities[j])) atol=1e-14
        end
    end
end
