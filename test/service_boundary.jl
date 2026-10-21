# This package reaches SpaceAGORA only through names the EDGServices contract
# lists. A contract change that drops a name the package uses, or a new use of a
# name the contract does not list, fails here, in this repository's CI and in
# SpaceAGORA's, which runs these tests against the core it is changing.
@testset "EDG uses only names the EDGServices contract lists" begin
    ES = SpaceAGORA.EDGServices
    # The facade's shape and its exact version refusal, as SpaceAGORA's conformance check defines them.
    SpaceAGORA.Conformance.test_service_facade(ES; version=SpaceAGORAEDG.REQUIRED_CONTRACT_VERSION)
    # Besides the two inventories, every adapter uses the version check.
    listed = Set{Symbol}((ES.IMPLEMENTED_FUNCTIONS..., ES.CONSUMED_SERVICES..., :CompatibilityError, :require_version))
    from_core(value) = try
        Base.moduleroot(value isa Module ? value : parentmodule(value)) === SpaceAGORA
    catch
        false
    end
    imported = Symbol[]
    for name in names(SpaceAGORAEDG; all=true, imported=true, usings=true)
        name === :SpaceAGORA && continue
        isdefined(SpaceAGORAEDG, name) && Base.binding_module(SpaceAGORAEDG, name) !== SpaceAGORAEDG || continue
        value = getglobal(SpaceAGORAEDG, name)
        from_core(value) || continue
        push!(imported, name)
        @test name in listed && isdefined(ES, name) && getglobal(ES, name) === value
    end
    @test length(imported) >= 20  # refuses a check that silently found no imports
    for file in readdir(joinpath(@__DIR__, "..", "src"); join=true)
        code = join((first(split(line, '#'; limit=2)) for line in eachline(file)), '\n')
        @test !occursin(r"SpaceAGORA\.(?!EDGServices\b)[A-Za-z_]", code)
        for spelled in eachmatch(r"SpaceAGORA\.EDGServices\.([A-Za-z_][A-Za-z0-9_!]*)", code)
            @test Symbol(spelled.captures[1]) in listed
        end
    end
end
