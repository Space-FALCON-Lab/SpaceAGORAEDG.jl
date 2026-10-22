# Heat-load, heat-rate and structural-load kernels. Each testset carries the name
# of the SpaceAGORA testset its assertions came from; the setup repeats that
# testset's public hook calls, so the kernels see the same state.

@testset "Energy depletion control switches and constraints" begin
    ctx_constraints = _edg_test_context(
        max_energy_submodes=(:heat_rate, :structural_load),
        heat_rate_limit_w_cm2=Inf,
        structural_load_limit_pa=0.5,
    )
    planet = ctx_constraints.args.environment_model.planet
    ctx_constraints.state.selected_mode[1] = :max_energy_depletion
    update_control!(ctx_constraints.control, ctx_constraints.u, ctx_constraints.p, 0.0, 1)

    sc_state = ctx_constraints.u.sc[1]
    pos = SVector{3, Float64}(sc_state.pos)
    vel = SVector{3, Float64}(sc_state.vel)
    env = probe(S._edg_targeting_prediction_environment, ctx_constraints.p, pos, vel, 0.0)
    track = K._edg_closed_form_heat_load_trajectory(
        ctx_constraints.config,
        ctx_constraints.p,
        ctx_constraints.spacecraft,
        pos,
        vel,
        Float64(sc_state.mass),
        0.0,
        env,
    )
    raw_high = fill(ctx_constraints.config.max_alpha_rad, length(track.time))
    alpha_heat = K._edg_constrained_heat_load_alpha_profile(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft,
        ctx_constraints.config.controlled_panel_links, track, raw_high;
        heat_rate_control=true, structural_control=false,
    )
    alpha_structural = K._edg_constrained_heat_load_alpha_profile(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft,
        ctx_constraints.config.controlled_panel_links, track, raw_high;
        heat_rate_control=false, structural_control=true,
    )
    alpha_high = K._edg_constrained_heat_load_alpha_profile(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft,
        ctx_constraints.config.controlled_panel_links, track, raw_high;
        heat_rate_control=true, structural_control=true,
    )
    @test alpha_high ≈ min.(alpha_heat, alpha_structural)

    shooting_env = probe(S._edg_targeting_prediction_environment, ctx_constraints.p, pos, vel, 0.0)
    shooting_coeffs = K._edg_heat_load_coefficients(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft, shooting_env,
    )
    shooting_scale_height = K._edg_heat_load_scale_height(ctx_constraints.p)
    shooting_costates = SVector{3, Float64}(1.0e9, 0.0, 0.0)
    low_altitude_state = SVector{9, Float64}(pos..., vel..., shooting_costates...)
    high_altitude_pos = normalize(pos) * (planet.Rp_e + 120e3)
    high_altitude_state = SVector{9, Float64}(high_altitude_pos..., vel..., shooting_costates...)
    low_altitude_derivative, _, _ = K._edg_heat_load_shooting_stage(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft,
        Float64(sc_state.mass), 0.0, 0.0, low_altitude_state,
        shooting_coeffs, shooting_scale_height, 0.05, ctx_constraints.config.max_alpha_rad;
        heat_rate_control=false, structural_control=false,
    )
    high_altitude_derivative, _, _ = K._edg_heat_load_shooting_stage(
        ctx_constraints.config, ctx_constraints.p, ctx_constraints.spacecraft,
        Float64(sc_state.mass), 0.0, 0.0, high_altitude_state,
        shooting_coeffs, shooting_scale_height, 0.05, ctx_constraints.config.max_alpha_rad;
        heat_rate_control=false, structural_control=false,
    )
    low_gravity = K._edg_prediction_gravity_acceleration(
        ctx_constraints.p, pos, vel, Float64(sc_state.mass), 0.0,
    )
    high_gravity = K._edg_prediction_gravity_acceleration(
        ctx_constraints.p, high_altitude_pos, vel, Float64(sc_state.mass), 0.0,
    )
    low_aero = SVector{3, Float64}(low_altitude_derivative[4:6]) - low_gravity
    high_aero = SVector{3, Float64}(high_altitude_derivative[4:6]) - high_gravity
    @test norm(low_aero) > norm(high_aero)

    infeasible_env = (
        dynamic_pressure=1.0e6,
        temperature=150.0,
        molecular_speed_ratio=10.0,
    )
    reference_drag_area = K._energy_depletion_struct_drag_area(
        ctx_constraints.spacecraft,
        infeasible_env.temperature,
        infeasible_env.molecular_speed_ratio,
        ctx_constraints.config.controlled_panel_links,
        ctx_constraints.config.max_alpha_rad,
        ctx_constraints.config,
    )
    minimum_drag = infeasible_env.dynamic_pressure * K._energy_depletion_struct_drag_area(
        ctx_constraints.spacecraft,
        infeasible_env.temperature,
        infeasible_env.molecular_speed_ratio,
        ctx_constraints.config.controlled_panel_links,
        ctx_constraints.config.min_alpha_rad,
        ctx_constraints.config,
    )
    @test minimum_drag > ctx_constraints.config.structural_load_limit_pa * reference_drag_area
    @test K._energy_depletion_struct_load_root_alpha(
        ctx_constraints.config,
        infeasible_env,
        ctx_constraints.spacecraft,
        ctx_constraints.config.controlled_panel_links,
        ctx_constraints.config.max_alpha_rad,
    ) == ctx_constraints.config.min_alpha_rad
end

@testset "EDG Phase 1 legacy equation parity" begin
    ctx = _edg_test_context(max_energy_submodes=(:heat_rate, :structural_load))

    taf = 1.0
    rho = 2.2e-7
    temperature = 150.0
    speed_ratio = 17.0
    alpha = 0.61
    gamma = ctx.args.environment_model.planet.γ
    gas_constant = ctx.args.environment_model.planet.R
    s_sin = speed_ratio * sin(alpha)
    legacy_heat_rate = rho * (1e-4 * taf * gas_constant * temperature * sqrt(gas_constant * temperature / (2pi))) * (
        (speed_ratio^2 + gamma / (gamma - 1.0) - (gamma + 1.0) / (2.0 * (gamma - 1.0))) *
        (exp(-s_sin^2) + sqrt(pi) * s_sin * (1.0 + erf(s_sin))) -
        0.5 * exp(-s_sin^2)
    )
    @test K._energy_depletion_heat_rate_calc(
        taf,
        rho,
        temperature,
        temperature,
        gas_constant,
        gamma,
        speed_ratio,
        alpha,
    ) ≈ legacy_heat_rate rtol=2e-14

    heat_limit = 0.15
    alpha_heat = K._energy_depletion_heatrate_root_alpha(
        taf=taf,
        rho=rho,
        T_p=temperature,
        R=gas_constant,
        gamma=gamma,
        S=speed_ratio,
        max_alpha=pi / 2,
        min_alpha=1e-4,
        heat_rate_limit=heat_limit,
        alpha_past=0.2,
    )
    @test K._energy_depletion_heat_rate_calc(
        taf,
        rho,
        temperature,
        temperature,
        gas_constant,
        gamma,
        speed_ratio,
        alpha_heat,
    ) ≈ heat_limit - 1e-5 atol=2e-10

    sigma = 0.9
    function legacy_plate(alpha)
        ss = speed_ratio * sin(alpha)
        exponential = exp(-ss^2)
        error_term = 1.0 + erf(ss)
        cn = ((((2.0 - sigma) / sqrt(pi)) * ss + sigma / 2.0) * exponential +
              ((2.0 - sigma) * (ss^2 + 0.5) + sigma * sqrt(pi) * ss / 2.0) * error_term) / speed_ratio^2
        ca = sigma * cos(alpha) * (exponential + sqrt(pi) * ss * error_term) / (sqrt(pi) * speed_ratio)
        return cn * cos(alpha) - ca * sin(alpha), ca * cos(alpha) + cn * sin(alpha)
    end
    panel_area = 3.76 * 1.93
    bus_area = 2.2 * 1.7
    cl_panel, cd_panel = legacy_plate(alpha)
    cl_bus, cd_bus = legacy_plate(pi / 2)
    expected_cl = (cl_panel * panel_area + cl_bus * bus_area) / (panel_area + bus_area)
    expected_cd = (cd_panel * panel_area + cd_bus * bus_area) / (panel_area + bus_area)
    actual_cl, actual_cd = K._edg_journal_spacecraft_aero_coefficients(
        ctx.spacecraft,
        speed_ratio,
        (2, 3),
        alpha,
    )
    @test actual_cl ≈ expected_cl rtol=2e-14
    @test actual_cd ≈ expected_cd rtol=2e-14

    times = [0.0, 100.0]
    f1, f2 = K._edg_closed_form_f1_f2(
        ctx.args.environment_model.planet,
        4350.0,
        deg2rad(-5.25),
        times,
        100.0,
    )
    @test f1 ≈ 4.6815 atol=1e-12
    @test f2[1] == 0.0
    @test f2[2] > 0.0
    @test K._edg_closed_form_density(ctx.args.environment_model.planet, 175e3) > 0.0
end

@testset "EDG no-switch plans are cached without a low-drag pulse" begin
    ctx = _edg_test_context(
        heat_load_limit_j_cm2=1e12,
        heat_rate_limit_w_cm2=Inf,
        structural_load_limit_pa=Inf,
    )
    # The SpaceAGORA testset's hook sequence, which leaves the cached no-switch plan.
    update_guidance!(ctx.guidance, ctx.u, ctx.p, 0.0, 1)
    for t in (30.0, 30.0 + 1/3, 31.0, 35.0)
        update_control!(ctx.control, ctx.u, ctx.p, t, 1)
    end
    original_position = copy(ctx.u.sc[1].pos)
    ctx.u.sc[1].pos .= (ctx.args.environment_model.planet.Rp_e + 300e3, 0.0, 0.0)
    update_control!(ctx.control, ctx.u, ctx.p, 40.0, 1)
    ctx.u.sc[1].pos .= original_position
    update_control!(ctx.control, ctx.u, ctx.p, 41.0, 1)
    @assert ctx.state.selected_mode[1] == :max_energy_depletion

    for switches in ((30.0,30.0), (Inf,Inf), (NaN,NaN), (40.0,30.0))
        ctx.state.heat_load_switches_s[1] = switches
        @test !K._edg_heat_load_low_drag_active(ctx.config,ctx.state,30.0,1)
    end
    ctx.state.heat_load_switches_s[1] = (30.0,40.0)
    for t in (30.0,35.0,40.0)
        @test K._edg_heat_load_low_drag_active(ctx.config,ctx.state,t,1)
    end
    for t in (29.0,41.0)
        @test !K._edg_heat_load_low_drag_active(ctx.config,ctx.state,t,1)
    end
    ctx.state.selected_mode[1] = :targeting
    @test !K._edg_heat_load_low_drag_active(ctx.config,ctx.state,35.0,1)
end

@testset "EDG prediction treats a zero-duration plan as no switch" begin
    ctx=_edg_test_context(heat_load_limit_j_cm2=1e12,heat_rate_limit_w_cm2=Inf,structural_load_limit_pa=Inf)
    sc=ctx.u.sc[1];pos=SVector{3,Float64}(sc.pos);vel=SVector{3,Float64}(sc.vel)
    times=[0.0,1/3,2/3,1.0]
    predict(sw)=KC._edg_integrated_max_energy_depletion_trajectory(ctx.state,
        ctx.config,ctx.p,ctx.spacecraft,pos,vel,Float64(sc.mass),30.0,times,sw;
        heat_rate_control=false,structural_control=false)
    empty=predict((Inf,Inf));zero=predict((30.0,30.0));window=predict((30.0,30.0+1/3))
    @test zero.alpha_profile == empty.alpha_profile
    @test zero.positions == empty.positions
    @test zero.velocities == empty.velocities
    @test zero.alpha_profile == fill(ctx.config.max_alpha_rad,length(times))
    @test window.alpha_profile[1:2] == fill(ctx.config.min_alpha_rad,2)
    @test window.alpha_profile[end] == ctx.config.max_alpha_rad
end

@testset "Switch endpoints, sentinels and panel selection" begin
    x = _edg_test_context(max_energy_submodes=(:heat_load,), heat_load_limit_j_cm2=30.0, heat_load_security_mode=false)
    x.state.selected_mode[1] = :max_energy_depletion
    x.state.heat_load_switch_solved[1] = true
    x.state.heat_load_switches_s[1] = (10.,20.)
    for (t, active) in ((prevfloat(10.),false),(10.,true),(nextfloat(10.),true),(20.,true),(nextfloat(20.),false))
        @test K._edg_heat_load_low_drag_active(x.config,x.state,t,1) == active
        @test K._edg_base_alpha(x.config,x.state,t,1) == (active ? x.config.min_alpha_rad : x.config.max_alpha_rad)
    end
    x.state.selected_mode[1] = :targeting; x.state.targeting_active[1] = true; x.state.targeting_switch_s[1] = 10.
    @test K._edg_base_alpha(x.config,x.state,10.0-1e-8,1) == x.config.max_alpha_rad
    @test K._edg_base_alpha(x.config,x.state,prevfloat(10.),1) == x.config.min_alpha_rad # Clock roundoff tolerance.
    @test K._edg_base_alpha(x.config,x.state,10.,1) == x.config.min_alpha_rad
    x.u.sc[1].heat_loads .= [0.,1.,90.]
    @test K._edg_max_heat_load_for_links(x.u.sc[1],x.config.controlled_panel_links) == 90.
    @test K._edg_max_heat_load_for_links((heat_loads=[NaN,-1.,2.],),(1,2,3,8)) == 2.
    @test K._edg_max_heat_load_for_links((pos=zeros(3),),(2,)) == 0.
end
