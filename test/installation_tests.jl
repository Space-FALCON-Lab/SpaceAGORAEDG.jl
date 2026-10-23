# Pure preflight tests; no remote acquisition, package installation or native data.
using Test, TOML
include(joinpath(@__DIR__, "..", "scripts", "setup_env.jl"))

@testset "EDG installation source and destination safeguards" begin
    mktempdir() do temporary
        temporary = realpath(temporary)
        core = joinpath(temporary, "core")
        mkpath(core)
        project = joinpath(core, "Project.toml")
        write(project, "name = \"SpaceAGORA\"\nuuid = \"afbfb69f-5c0b-4832-b760-43725dff8540\"\nversion = \"0.2.0\"\n")
        destination = joinpath(temporary, "environment")
        active = Base.active_project()
        plan = EDGInstallation.installation_plan(destination; core_path=core, core_revision="")
        @test plan.core.path == core
        @test plan.core.revision === nothing
        @test plan.destination == destination
        @test !ispath(destination)
        @test Base.active_project() == active
        @test_throws ArgumentError EDGInstallation.installation_plan(core; core_path=core)
        @test_throws ArgumentError EDGInstallation.installation_plan(joinpath(core, "new", "environment"); core_path=core)
        @test_throws ArgumentError EDGInstallation.installation_plan(EDGInstallation.PACKAGE_ROOT; core_path=core)
        @test_throws ArgumentError EDGInstallation.installation_plan(destination; core_path=core, core_revision="a"^40)
        @test_throws ArgumentError EDGInstallation.installation_plan(destination; core_path="", core_revision="main")
        alias = joinpath(temporary, "core-alias")
        symlink(core, alias; dir_target=true)
        @test_throws ArgumentError EDGInstallation.installation_plan(joinpath(alias, "new", "environment"); core_path=core)
        dangling = joinpath(temporary, "dangling")
        symlink(joinpath(temporary, "not-created"), dangling; dir_target=true)
        @test_throws ArgumentError EDGInstallation.installation_plan(joinpath(dangling, "env"); core_path=core)
        mkpath(destination)
        write(joinpath(destination, "keep.txt"), "User data remains untouched.")
        @test_throws ArgumentError EDGInstallation.installation_plan(destination; core_path=core)
        @test read(joinpath(destination, "keep.txt"), String) == "User data remains untouched."
        write(project, "name = \"Other\"\nuuid = \"00000000-0000-0000-0000-000000000000\"\n")
        @test_throws ArgumentError EDGInstallation.installation_plan(joinpath(temporary, "other-env"); core_path=core)
        @test Base.active_project() == active
    end
end

@testset "Standalone and reusable CI pin the same core" begin
    root = joinpath(@__DIR__, "..")
    installer = TOML.parsefile(joinpath(root, "CoreSource.toml"))
    contributor = TOML.parsefile(joinpath(root, "SpaceAGORASource.toml"))
    for key in ("url", "uuid", "rev")
        @test contributor[key] == installer[key]
    end
end
