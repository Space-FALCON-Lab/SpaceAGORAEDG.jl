# Load the exact package entry point in a fresh process against older facade
# shapes. Neither child has the numerical dependencies on its load path.
using Test
@testset "EDG refuses unsupported core before numerical loading" begin
    source = joinpath(@__DIR__, "..", "src", "SpaceAGORAEDG.jl")
    for (fixture, expected) in (
        ("module SpaceAGORA\nend\n", "requires a SpaceAGORA build with EDGServices"),
        ("module SpaceAGORA\nmodule EDGServices\nrequire_version(v) = error(\"fixture unsupported contract: \" * string(v))\nend\nend\n", "fixture unsupported contract: 1.0.0"),
    )
        mktempdir() do directory
            path = joinpath(directory, "SpaceAGORA", "src")
            mkpath(path)
            write(joinpath(path, "SpaceAGORA.jl"), fixture)
            check = """
                problem = try; include($(repr(source))); nothing; catch e; e; end
                problem === nothing && error("unsupported core unexpectedly loaded")
                occursin($(repr(expected)), sprint(showerror, problem)) || throw(problem)
                if isdefined(Main, :SpaceAGORAEDG)
                    isdefined(Main.SpaceAGORAEDG, :control_decision!) && error("kernel defined before refusal")
                end
                any(nameof(module_value) in (:NLsolve, :Roots, :SpecialFunctions)
                    for module_value in values(Base.loaded_modules)) && error("optional numerical library loaded before refusal")
                println("early_refusal_verified")
                """
            command = `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no -e $check`
            result = read(addenv(command, "JULIA_LOAD_PATH" => directory * ":@stdlib"), String)
            @test occursin("early_refusal_verified", result)
        end
    end
end
