# Passage heat: the largest heat load over the listed panel links, measured from
# the entry baseline that SpaceAGORA's heat accounting captures, never below zero,
# skipping non-finite values, and read from the exit snapshot once there is one.
# SpaceAGORA's tests check the baselines and snapshots; these check the formula,
# on the values of SpaceAGORA's passage-heat bookkeeping tests.

@testset "EDG passage heat formula" begin
    state = AerobrakingEnergyDepletionState(num_sats=2)
    satellite(loads) = (pos=zeros(3), vel=zeros(3), mass=461.0, heat_loads=loads)
    state.heat_load_entry_j_cm2[1] = [999.0, 100.0, 20.0]
    current = satellite([1099.0, 105.0, 28.0])
    @test K._edg_max_heat_load_for_links(current, (2,3)) == 105.0
    @test K._edg_pass_heat_load_for_links(current, (2,3), state, 1) == 8.0
    @test K._edg_pass_heat_load_for_links(current, (2,), state, 1) == 5.0
    @test K._edg_pass_heat_load_for_links(current, (3,), state, 1) == 8.0
    # After the exit snapshot, coast heating does not count.
    state.heat_load_exit_j_cm2[1] = [1099.0, 105.0, 28.0]
    @test K._edg_pass_heat_load_for_links(satellite([1099.0, 155.0, 78.0]), (2,3), state, 1) == 8.0
    # A new entry baseline starts the next passage at zero.
    state.heat_load_entry_j_cm2[1] = [1099.0, 155.0, 78.0]
    state.heat_load_exit_j_cm2[1] = Float64[]
    @test K._edg_pass_heat_load_for_links(satellite([1099.0, 155.0, 78.0]), (2,3), state, 1) == 0.0
    # Each spacecraft has its own baseline.
    state.heat_load_entry_j_cm2[1] = [0.0, 26.0, 20.0]
    state.heat_load_entry_j_cm2[2] = [0.0, 80.0, 90.0]
    @test K._edg_pass_heat_load_for_links(satellite([0.0, 30.0, 28.0]), (2,3), state, 1) == 8.0
    @test K._edg_pass_heat_load_for_links(satellite([0.0, 89.0, 92.0]), (2,3), state, 2) == 9.0
    # The assembled replan callbacks' entry and later loads.
    state.heat_load_entry_j_cm2[1] = [100.0, 6.0, 6.0]
    @test K._edg_pass_heat_load_for_links(satellite([100.0, 8.0, 9.0]), (2,3), state, 1) == 3.0
    @test K._edg_pass_heat_load_for_links(satellite([100.0, 40.0, 41.0]), (2,3), state, 1) == 35.0
    state.heat_load_entry_j_cm2[1] = [0.0, 26.0, 20.0]
    # Never below zero; non-finite loads and missing links are skipped; a link
    # without a baseline value counts from zero; no heat loads, no passage heat.
    @test K._edg_pass_heat_load_for_links(satellite([0.0, 20.0, 10.0]), (2,3), state, 1) == 0.0
    @test K._edg_pass_heat_load_for_links(satellite([0.0, NaN, 21.0]), (2,3,8), state, 1) == 1.0
    state.heat_load_entry_j_cm2[1] = [0.0, 26.0]
    @test K._edg_pass_heat_load_for_links(satellite([0.0, 27.0, 4.0]), (2,3), state, 1) == 4.0
    @test K._edg_pass_heat_load_for_links((pos=zeros(3),), (2,3), state, 1) == 0.0
end
