# One package load order in a fresh process:
#   julia --project=<environment> test/load_order.jl core-first|edg-first
# Core-first also checks that SpaceAGORA, before this package loads, refuses an EDG
# run without changing its state. Both orders then check the same service contract.
using Test, Serialization
length(ARGS) == 1 && only(ARGS) in ("core-first", "edg-first") || error("Pass core-first or edg-first")
const ORDER = only(ARGS)

if ORDER == "core-first"
    using SpaceAGORA
    @testset "SpaceAGORA refuses EDG guidance without this package" begin
        ES = SpaceAGORA.EDGServices
        @test !ES.available()
        @test Base.get_extension(SpaceAGORA, :SpaceAGORAEDGExt) === nothing
        @test_throws ES.EDGUnavailableError ES.require_provider()
        # The example's configuration uses core names only; this copy changes only
        # its import line, so building it does not load the package.
        example = joinpath(@__DIR__, "..", "examples", "analytic_atmosphere.jl")
        source = read(example, String)
        imports = "using SpaceAGORA, SpaceAGORAEDG\n"
        @test count(imports, source) == 1
        Base.include_string(Main, replace(source, imports => "using SpaceAGORA\n"), example)
        configuration = Base.invokelatest(build_analytic_edg)
        state = only(configuration.guidance_model.guidance_effectors).state
        @test only(configuration.control_model.control_effectors).state === state
        # A state carried over from an earlier run, so that a refusal which first
        # initialized or reset the state, or started stepping, would change it.
        state.selected_mode[1] = :targeting
        state.targeting_active[1] = true
        state.energy_bracketing_count[1] = 3
        state.last_alpha_rad[1] = 0.123
        state.last_heat_rate_w_cm2[1] = 0.05
        state.last_dynamic_pressure_pa[1] = 0.2
        state.heat_load_entry_j_cm2[1] = [1.5]
        snapshot(value) = (io = IOBuffer(); serialize(io, value); take!(io))
        before_state = snapshot(state)
        before_vehicle = snapshot(configuration.dynamics_model.spacecraft)
        # Without isolation a started run would update this state, so the refusal
        # must come before any initialization or stepping.
        @test_throws ES.EDGUnavailableError run_simulation(configuration; isolate_state=false)
        @test snapshot(state) == before_state
        @test snapshot(configuration.dynamics_model.spacecraft) == before_vehicle
        @test only(configuration.control_model.control_effectors).state === state
        @test !ES.available()
        @test !any(id -> id.name == "SpaceAGORAEDG", keys(Base.loaded_modules))
    end
    using SpaceAGORAEDG
else
    using SpaceAGORAEDG
    using SpaceAGORA
end

@testset "EDG service contract after $ORDER loading" begin
    ES = SpaceAGORA.EDGServices
    extension = Base.get_extension(SpaceAGORA, :SpaceAGORAEDGExt)
    @test extension !== nothing
    @test ES.available()
    @test ES.require_provider() === extension
    @test ES.CONTRACT_VERSION == SpaceAGORAEDG.REQUIRED_CONTRACT_VERSION
    @test SpaceAGORAEDG.AerobrakingEnergyDepletionConfig === SpaceAGORA.AerobrakingEnergyDepletionConfig
    @test SpaceAGORAEDG.AerobrakingEnergyDepletionState === SpaceAGORA.AerobrakingEnergyDepletionState
    @test all(name -> isdefined(SpaceAGORAEDG, name), ES.IMPLEMENTED_FUNCTIONS)
    # Initialization can repeat; it checks the contract again and defines nothing.
    counts = () -> map(name -> length(methods(getproperty(ES, name))), ES.IMPLEMENTED_FUNCTIONS)
    before = counts()
    @test SpaceAGORAEDG.__init__() === nothing
    @test extension.__init__() === nothing
    @test counts() == before
    @test ES.require_provider() === extension
end
