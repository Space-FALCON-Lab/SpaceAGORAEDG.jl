# The control decision against its kernel composition, moved here from SpaceAGORA's
# test/gnc/aerobraking/energy_depletion_ownership_tests.jl at v0.6.0 (0487e8226).
# SpaceAGORA checks that its control hook applies the decision; this checks that the
# decision gives the state and command of its helper kernels called in order.

function reference_control!(config, state, links, u, p, t, i)
    1 <= i <= length(state.selected_mode) || return nothing
    if state.selected_mode[i] == :inactive && !(:targeting in config.guidance_modes)
        state.selected_mode[i] = (:max_energy_depletion in config.guidance_modes) ? :max_energy_depletion : :safe_low_drag
    end
    sc = S._edg_control_sat_state(u, i)
    env = probe(S._edg_environment_state, p, u, Float64(t), i)
    spacecraft = p.args.dynamics_model.spacecraft[i]
    pos, vel, mass = S._edg_control_pos_vel_mass(sc)
    heat_load = K._edg_max_heat_load_for_links(sc, links)
    pass_heat = K._edg_pass_heat_load_for_links(sc, links, state, i)
    K._edg_recompute_switches!(config, state, p, env, spacecraft, pos, vel, mass, pass_heat, Float64(t), i)
    K._edg_update_heat_load_security!(config, state, p, env, spacecraft, pos, vel, mass, pass_heat, Float64(t), i)
    heat_load_low_drag_active = K._edg_heat_load_low_drag_active(config, state, Float64(t), i)
    base_alpha = K._edg_base_alpha(config, state, Float64(t), i)
    return K._edg_command_alpha!(config, state, p, links, env, spacecraft, base_alpha, heat_load,
        heat_load_low_drag_active, i; pass_heat_load_j_cm2=pass_heat)
end

@testset "Decision, telemetry and panel application match retained hook sequence" begin
    for mode in (:inactive, :safe_low_drag, :targeting, :max_energy_depletion),
        t in (prevfloat(10.0), 10.0, nextfloat(10.0), 20.0, nextfloat(20.0))
        x = _edg_test_context(heat_load_limit_j_cm2=30.0)
        x.state.selected_mode[1] = mode
        x.state.targeting_active[1] = mode == :targeting
        x.state.targeting_switch_s[1] = 10.0
        x.state.heat_load_switches_s[1] = (10.0,20.0)
        x.state.heat_load_switch_solved[1] = true
        old = deepcopy(x)
        links = x.control.aoa_effector.controlled_panel_links
        result = S.control_decision!(x.state, x.config, links, x.u, x.p, t, 1)
        alpha = reference_control!(old.config, old.state, links, old.u, old.p, t, 1)
        @test isequal(state_values(x.state), state_values(old.state))
        @test result.command.alpha_command === alpha
    end
end
