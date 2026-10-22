# The integration checks run against a released SpaceAGORA: the core commit
# pinned in CoreSource.toml must be the commit of a SpaceAGORA release tag, and this
# package's compatibility range and version family must admit that release. Needs
# network access to the core repository; CI runs it as its own job.
#   julia --startup-file=no test/core_release_pin.jl
using Pkg, Test, TOML

const ROOT = joinpath(@__DIR__, "..")
pin = TOML.parsefile(joinpath(ROOT, "CoreSource.toml"))

# Release versions whose tag points at `revision` (an annotated tag through its ^{} line).
function release_versions(url, revision)
    versions = VersionNumber[]
    for line in readlines(Cmd(["git", "ls-remote", "--tags", url]))
        commit, ref = split(line, '\t')
        tag = match(r"^refs/tags/v(\d+\.\d+\.\d+)(\^\{\})?$", ref)
        tag !== nothing && commit == revision && push!(versions, VersionNumber(tag.captures[1]))
    end
    return unique!(versions)
end

@testset "The pinned core is a SpaceAGORA release" begin
    versions = release_versions(pin["url"], pin["rev"])
    @test length(versions) == 1
    if length(versions) == 1
        release = only(versions)
        println("Pinned core $(pin["rev"]) is SpaceAGORA v$release.")
        @test pin["version_family"] == "$(release.major).$(release.minor)"
        compat = TOML.parsefile(joinpath(ROOT, "Project.toml"))["compat"]["SpaceAGORA"]
        @test release in Pkg.Versions.semver_spec(compat)
    end
end
