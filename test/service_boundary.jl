# This package reaches SpaceAGORA only through names the EDGServices contract
# lists. A contract change that drops a name the package uses, or a new use of a
# name the contract does not list, fails here, in this repository's CI and in
# SpaceAGORA's, which runs these tests against the core it is changing. The
# check covers the runtime source under src/, in module code and function bodies,
# through the bindings of SpaceAGORA modules that test/core_access.jl follows and
# within the limits it states; the tests' private fixtures are outside it.
include("core_access.jl")
using .CoreAccess

@testset "EDG uses only names the EDGServices contract lists" begin
    ES = SpaceAGORA.EDGServices
    # The facade's shape and its exact version refusal, as SpaceAGORA's conformance check defines them.
    SpaceAGORA.Conformance.test_service_facade(ES; version=SpaceAGORAEDG.REQUIRED_CONTRACT_VERSION)

    # From SpaceAGORA only the facade; from the facade its two inventories and the
    # version check every adapter makes.
    listed = Set{Symbol}((ES.IMPLEMENTED_FUNCTIONS..., ES.CONSUMED_SERVICES..., :CompatibilityError, :require_version))
    allowed(m, name) = (m === SpaceAGORA && name === :EDGServices) || (m === ES && name in listed)
    policy = CorePolicy(SpaceAGORA, allowed, (SpaceAGORA, ES))

    @test isempty(runtime_violations(policy, SpaceAGORAEDG))
    sources = [joinpath(directory, file) for (directory, _, files) in walkdir(joinpath(@__DIR__, "..", "src"))
               for file in files if endswith(file, ".jl")]
    found, used, known = source_violations(policy, sources)
    @test isempty(found)
    # Every binding of a SpaceAGORA module is one the source check follows.
    @test isempty(unknown_module_bindings(policy, SpaceAGORAEDG, known))
    # A check that saw nothing would pass too: the source does name the facade's services.
    @test length(sources) >= 9
    @test count(((m, _),) -> m === ES, used) >= 20
end
