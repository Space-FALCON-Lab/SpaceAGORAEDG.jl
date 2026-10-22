# This package reaches SpaceAGORA only through names the EDGServices contract
# lists. A contract change that drops a name the package uses, or a new use of a
# name the contract does not list, fails here, in this repository's CI and in
# SpaceAGORA's, which runs these tests against the core it is changing. The
# check covers the runtime source under src/, in module code and function bodies,
# through the bindings of SpaceAGORA modules that test/core_access.jl follows and
# within the limits it states; the tests' private fixtures are outside it.
include("core_access.jl")
using .CoreAccess

# Names that occur in code outside `import`, `using` and `export`: plain names and
# the names after a dot in qualified accesses.
function code_names!(found, ex)
    if ex isa Symbol
        push!(found, ex)
    elseif ex isa Expr && !(ex.head in (:import, :using, :export))
        if ex.head === :. && length(ex.args) == 2 && ex.args[2] isa QuoteNode
            code_names!(found, ex.args[1])
            ex.args[2].value isa Symbol && push!(found, ex.args[2].value)
        else
            foreach(arg -> code_names!(found, arg), ex.args)
        end
    end
    return found
end
unused_names(exprs, names) = (found = foldl(code_names!, exprs; init=Set{Symbol}());
    sort!([name for name in names if !(name in found)]))
# The source with every use of `name` outside imports renamed away.
without_uses(ex, name) = ex === name ? :__removed_use__ :
    ex isa QuoteNode && ex.value === name ? QuoteNode(:__removed_use__) :
    ex isa Expr && !(ex.head in (:import, :using, :export)) ? Expr(ex.head, map(arg -> without_uses(arg, name), ex.args)...) : ex

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

    # Consistency: this package reaches exactly the services the contract lists,
    # and defines the two decisions itself, so the contract lists nothing it does
    # not use.
    reached = Set{Symbol}(name for (m, name) in used if m === ES)
    @test setdiff(reached, (:CompatibilityError, :require_version)) == Set(ES.CONSUMED_SERVICES)
    for name in ES.IMPLEMENTED_FUNCTIONS
        @test isdefined(SpaceAGORAEDG, name) && parentmodule(getglobal(SpaceAGORAEDG, name)) === SpaceAGORAEDG
    end

    # Use: each listed name is named in code outside the import that brings it in.
    # An import kept after its last use passes the consistency check but fails here.
    exprs = [Meta.parseall(read(file, String); filename=file) for file in sources]
    listed_names = (ES.IMPLEMENTED_FUNCTIONS..., ES.CONSUMED_SERVICES...)
    @test isempty(unused_names(exprs, listed_names))
    # Negative control: keep every import and remove the uses of one service;
    # only that service is reported.
    for name in (:_edg_ephemeris_time, :frame_state, :rtolatlong)
        @test name in ES.CONSUMED_SERVICES
        @test unused_names(map(ex -> without_uses(ex, name), exprs), listed_names) == [name]
    end
end
