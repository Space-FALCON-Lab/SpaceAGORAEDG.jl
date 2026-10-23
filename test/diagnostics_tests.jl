# Diagnostics: the command's physical-limit statuses and the typed costates of
# the heat-load profile, moved here from SpaceAGORA's
# test/gnc/aerobraking/edg_feasibility_tests.jl (the whole file) and
# test/unit/legacy_guidance_diagnostic_contract_tests.jl (its costate testset).
# These checks exercise production control and physical telemetry without changing limits.

@testset "EDG command parity and physical-limit diagnostics" begin
    for modes in ((:max_energy_depletion,), (:targeting,:max_energy_depletion)),
            security in (false,true), base in (0.4,pi/2), load in (29.0,30.0,34.56)
        c=_edg_test_context(guidance_modes=modes,max_energy_submodes=(:heat_load,),heat_load_limit_j_cm2=30.0)
        fields=(; (key=>getfield(c.config,key) for key in fieldnames(typeof(c.config)))...)
        config=AerobrakingEnergyDepletionConfig(;merge(fields,(heat_load_security_mode=security,))...)
        env=probe(S._edg_environment_state,c.p,c.u,0.0,1)
        angle=K._edg_command_alpha!(config,c.state,c.p,config.controlled_panel_links,env,c.spacecraft,base,load,false,1;
            pass_heat_load_j_cm2=load)
        @test angle == base # Diagnostic heat status must not add a new command policy.
        @test c.state.last_heat_budget_status[1] == (load >= 30.0 ? :exhausted : :available)
        @test c.state.last_heat_load_j_cm2[1] == load
        @test c.state.last_heat_rate_status[1] == :disabled
        @test c.state.last_structural_load_status[1] == :disabled
    end
    for (enabled,limit,value,minimum,status) in (
            (false,0.5,1.0,0.6,:disabled), (true,Inf,1.0,0.6,:unbounded),
            (true,NaN,1.0,0.6,:invalid_limit), (true,-1.0,1.0,0.6,:invalid_limit),
            (true,0.5,NaN,0.4,:unobserved), (true,0.5,0.5,0.4,:within_limit),
            (true,0.5,0.6,0.4,:command_above_limit),
            (true,0.5,0.6,0.55,:above_limit_at_minimum_angle),
            (true,0.5,0.4,0.55,:within_limit))
        @test K._edg_constraint_status(enabled,limit,value,minimum) == status
    end
    for (submodes,limit,load,expected) in (
            ((:heat_rate,),30.0,34.56,:disabled), ((:heat_load,),Inf,34.56,:unbounded),
            ((:heat_load,),0.0,34.56,:invalid_limit), ((:heat_load,),NaN,34.56,:invalid_limit),
            ((:heat_load,),30.0,NaN,:unobserved))
        config=AerobrakingEnergyDepletionConfig(max_energy_submodes=submodes,heat_load_limit_j_cm2=limit)
        @test K._edg_heat_budget_status(config,load)==expected
    end
    c=_edg_test_context(heat_load_limit_j_cm2=30.0)
    env=probe(S._edg_environment_state,c.p,c.u,0.0,1)
    for scale in (1.0,1e-6)
        scaled=merge(env,(rho=env.rho*scale,dynamic_pressure=env.dynamic_pressure*scale))
        angle=K._edg_command_alpha!(c.config,c.state,c.p,c.config.controlled_panel_links,scaled,c.spacecraft,c.config.min_alpha_rad,34.56,false,1;
            pass_heat_load_j_cm2=34.56)
        @test angle==c.config.min_alpha_rad
        @test c.state.last_heat_budget_status[1]==:exhausted
        @test c.state.last_heat_rate_w_cm2[1]==c.state.last_minimum_heat_rate_w_cm2[1]
        @test c.state.last_structural_load_pa[1]==c.state.last_minimum_structural_load_pa[1]
        @test c.state.last_structural_load_status[1]==(scale==1.0 ? :above_limit_at_minimum_angle : :within_limit)
        @test c.state.last_heat_rate_w_cm2[1]>0.0 # Minimum angle cannot erase incoming heat.
    end
    # Disabling only accumulated-heat control preserves the existing angle choice.
    c=_edg_test_context(max_energy_submodes=(:heat_rate,),heat_load_limit_j_cm2=30.0)
    env=probe(S._edg_environment_state,c.p,c.u,0.0,1)
    a=K._edg_command_alpha!(c.config,c.state,c.p,c.config.controlled_panel_links,env,c.spacecraft,pi/2,29.0,false,1;
        pass_heat_load_j_cm2=29.0)
    b=K._edg_command_alpha!(c.config,c.state,c.p,c.config.controlled_panel_links,env,c.spacecraft,pi/2,34.56,false,1;
        pass_heat_load_j_cm2=34.56)
    @test a==b
    @test c.state.last_heat_budget_status[1]==:disabled
end

@testset "typed costates remain separate call-local prediction arrays" begin
    track = (time=[0.0, 2.0], speed=[4.0, 5.0], h=[0.0, 0.0],
        gamma=[-0.2, 0.0], rho=[0.0, 0.0])
    seed = [0.4, 0.7]
    coeffs = (cd_slope=2.0, cd_low=1.0, cl_low=0.0)
    planet = (μ=100.0, Rp_e=10.0, g_ref=1.0)
    before = deepcopy(track)
    threshold, costate = K._edg_heat_load_lambdas(track, seed, coeffs, 3.0, 2.0, planet, 10.0, 4.0)
    @test threshold ≈ 6.0 .* track.speed ./ pi
    @test costate ≈ [4.6, 5.0]
    @test track == before
    @test seed == [0.4, 0.7]
    other_threshold, other_costate = K._edg_heat_load_lambdas(track, seed, coeffs, 3.0, 2.0, planet, 10.0, 4.0)
    @test threshold !== other_threshold
    @test costate !== other_costate
    negative_slope, _ = K._edg_heat_load_lambdas(track, seed,
        merge(coeffs, (cd_slope=-2.0,)), 3.0, 2.0, planet, 10.0, 4.0)
    @test negative_slope == threshold # The typed denominator uses abs(cd_slope).
    negative_gain, _ = K._edg_heat_load_lambdas(track, seed, coeffs, 3.0, 2.0, planet, 10.0, -4.0)
    @test negative_gain == -threshold

    # Exact equality selects the maximum angle in this algorithm.
    one_point = (time=[0.0], speed=[5.0], h=[0.0], gamma=[0.0], rho=[0.0])
    config = (min_alpha_rad=0.1, max_alpha_rad=1.2)
    profile, boundary, lambda = K._edg_heat_load_alpha_profile(config, one_point,
        (cd_slope=2/pi, cd_low=1.0, cl_low=0.0), 1.0, 1.0, planet, 10.0, 1.0, [0.7])
    @test boundary == lambda == [5.0]
    @test profile == [config.max_alpha_rad]
    profile_low, _, _ = K._edg_heat_load_alpha_profile(config, one_point,
        (cd_slope=2/pi, cd_low=1.0, cl_low=0.0), 1.0, 1.0, planet, 10.0, 2.0, [0.7])
    @test profile_low == [config.min_alpha_rad]

    # Relative prediction samples become elapsed simulation switch timestamps.
    time_track = (time=[0.0, 2.0, 7.0, 10.0],)
    @test K._edg_low_alpha_switch_window(config, 123.0, time_track, [1.2, 0.1, 0.1, 1.2]) == (125.0, 130.0)
    @test K._edg_low_alpha_switch_window(config, 123.0, time_track, fill(1.2, 4)) == (Inf, Inf)
    @test K._edg_low_alpha_switch_window(config, 123.0, time_track, [1.2, 0.1, 1.2, 1.2]) == (Inf, Inf)
end
