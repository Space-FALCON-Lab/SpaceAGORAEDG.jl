using Test, SpaceAGORA, SpaceAGORAEDG, StaticArrays
const S = SpaceAGORA.EDGServices
const InternalServices = SpaceAGORA.SimulationModel.EDGServices
include(joinpath(@__DIR__, "..", "examples", "analytic_atmosphere.jl"))

# This test-only dispatch records the lease that the real core invoker provides.
# It does not replace any numerical method or run inside a propagated model.
mutable struct LeaseRecorder
    context::Any
    fail::Bool
end
function SpaceAGORAEDG._edg_constraint_status(recorder::LeaseRecorder, p::S.AbstractPredictionContext)
    recorder.context = p
    constants = S.planet_constants(p)
    recorder.fail && error("test provider failure")
    return constants
end

@testset "EDG package service contract" begin
    @test S.CONTRACT_VERSION == SpaceAGORAEDG.REQUIRED_CONTRACT_VERSION == v"2.0.0"
    @test isnothing(SpaceAGORAEDG.require_version(v"2.0.0"))
    # The previous contract, whose decision services took the configuration first.
    @test_throws S.CompatibilityError SpaceAGORAEDG.require_version(v"1.0.0")
    @test S.available()
    @test SpaceAGORAEDG.AerobrakingEnergyDepletionConfig === AerobrakingEnergyDepletionConfig
    @test SpaceAGORAEDG.AerobrakingEnergyDepletionState === AerobrakingEnergyDepletionState
    @test SpaceAGORAEDG.AerobrakingControlCommand === S.AerobrakingControlCommand
    @test SpaceAGORAEDG.EDGControlDecision === S.EDGControlDecision
    @test all(name -> isdefined(SpaceAGORAEDG, name), S.COMPATIBILITY_FUNCTIONS)
    # Contract 2.0.0: the EDG run state first in both decision services.
    State, Config, Context = AerobrakingEnergyDepletionState, AerobrakingEnergyDepletionConfig, S.AbstractPredictionContext
    @test hasmethod(SpaceAGORAEDG.guidance_decision!, Tuple{State, Config, Any, Context, Float64, Int})
    @test !hasmethod(SpaceAGORAEDG.guidance_decision!, Tuple{Config, State, Any, Context, Float64, Int})
    @test hasmethod(SpaceAGORAEDG.control_decision!, Tuple{State, Config, Tuple{Vararg{Int}}, Any, Context, Float64, Int})
    @test !hasmethod(SpaceAGORAEDG.control_decision!, Tuple{Config, State, Tuple{Vararg{Int}}, Any, Context, Float64, Int})
    @test !isdefined(S, :ODEParams)
    @test !isdefined(SpaceAGORAEDG, :ODEParams)
end

@testset "Copied observations and expiring prediction queries" begin
    configuration = build_analytic_edg()
    p = SpaceAGORA.SimulationModel.ODEParams(n_sats=1, args=configuration)
    recorder = LeaseRecorder(nothing, false)
    constants = InternalServices._invoke_kernel(:_edg_constraint_status, recorder, p)
    @test constants.μ == configuration.environment_model.planet.μ
    context = recorder.context
    @test isempty(propertynames(context))
    @test_throws ArgumentError context.query
    @test_throws ArgumentError context.active
    @test_throws ArgumentError S.planet_constants(context)
    @test_throws ArgumentError getfield(context, :query)(Val(:planet))
    recorder.fail = true
    @test_throws ErrorException InternalServices._invoke_kernel(:_edg_constraint_status, recorder, p)
    @test_throws ArgumentError S.planet_constants(recorder.context)
    @test_throws MethodError S.planet_constants(p)
    @test_throws MethodError S._edg_ephemeris_time(p, 0.0)

    geometry = InternalServices._geometry_values(only(configuration.dynamics_model.spacecraft))
    original = geometry.links[2].dims
    configuration.dynamics_model.spacecraft[1].links[2].dims[1] += 1.0
    @test geometry.links[2].dims == original
    @test geometry.links isa Tuple
    @test geometry.links[2].dims isa SVector
    position = [1.0, 2.0, 3.0]
    heat = [4.0, 5.0]
    observation = InternalServices._observation_values((sc=[(pos=position, vel=zeros(3), mass=1.0, heat_loads=heat)],))
    position[1] = 99.0; heat[1] = 99.0
    @test observation.sc[1].pos[1] == 1.0
    @test observation.sc[1].heat_loads == (4.0, 5.0)
end

@testset "Installed EDG analytic-atmosphere run and isolation" begin
    example = run_analytic_edg()
    template = only(example.configuration.control_model.control_effectors).state
    actual = only(example.result.configuration.control_model.control_effectors).state
    @test actual !== template
    @test actual === only(example.result.configuration.guidance_model.guidance_effectors).state
    @test isnan(only(template.last_alpha_rad))
    @test isfinite(only(actual.last_alpha_rad))
    @test only(actual.last_dynamic_pressure_pa) > 0
    @test only(actual.last_heat_rate_w_cm2) > 0
    @test only(actual.selected_mode) == :max_energy_depletion
    @test !isempty(example.result.table.time)
    @test all(isfinite, example.result.table.time)
    @test isapprox(last(example.result.table.time), 2.0; atol=1e-10)
    @test isempty(example.result.files)
    rerun = run_simulation(example.configuration; return_results=true)
    @test isequal(rerun.table, example.result.table)
    @test only(rerun.configuration.control_model.control_effectors).state !== actual
end

include("compatibility_tests.jl")
