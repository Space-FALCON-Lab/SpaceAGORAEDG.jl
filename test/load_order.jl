# One package load order in a fresh process:
#   julia --project=<environment> test/load_order.jl core-first|edg-first
# Core-first also checks that SpaceAGORA, before this package loads, refuses an EDG
# run without changing its state. Both orders then check the same service contract.
using Test
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
        @test isnan(only(state.last_alpha_rad))
        # Without isolation a started run would update this state, so the refusal
        # must come before any stepping.
        @test_throws ES.EDGUnavailableError run_simulation(configuration; isolate_state=false)
        @test isnan(only(state.last_alpha_rad))
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
    @test all(name -> isdefined(SpaceAGORAEDG, name), ES.COMPATIBILITY_FUNCTIONS)
    # Initialization can repeat; it checks the contract again and defines nothing.
    counts = () -> map(name -> length(methods(getproperty(ES, name))), ES.IMPLEMENTED_FUNCTIONS)
    before = counts()
    @test SpaceAGORAEDG.__init__() === nothing
    @test extension.__init__() === nothing
    @test counts() == before
    @test ES.require_provider() === extension
end
