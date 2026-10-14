module NativeReferencePaths
using SHA, TOML

const recipe_directory = @__DIR__
const companion_directory = normpath(joinpath(@__DIR__, "..", ".."))
required(name) = isempty(get(ENV, name, "")) ? error("Set $name; see the native reference README.") : ENV[name]
const core_directory = realpath(required("EDG_CORE_PATH"))
const gram_assets = realpath(required("EDG_GRAM_ASSET_ROOT"))
const bridge_library = realpath(required("EDG_NATIVE_LIBRARY"))
const output_directory = abspath(required("EDG_OUTPUT_DIR"))
const fixture_relative = "test/gnc/aerobraking/energy_depletion_gnc_tests.jl"
const fixture_sha256 = "335b3891f41beadae2049fa487365363b9c839c37d70247cba5317d0435b49db"
const kernels = ("pck/pck00011.tpc", "spk/planets/de440_GRAM.bsp",
    "lsk/naif0012.tls", "spk/planets/de440s.bsp", "spk/satellites/sat441_GRAM.bsp")

filehash(path) = open(io -> bytes2hex(sha256(io)), path)
inside(path, root) = first(splitpath(relpath(path, root))) != ".."
function canonical_output(path)
    tail = String[]
    while !ispath(path)
        islink(path) && error("Output path contains a dangling symlink: $path")
        pushfirst!(tail, basename(path))
        path = dirname(path)
    end
    isdir(path) || error("Output must be a directory.")
    return joinpath(realpath(path), tail...)
end

function preflight()
    case = get(ENV, "EDG_CASE", "depletion")
    case in ("depletion", "two_pass", "targeting") || error("EDG_CASE must be depletion, two_pass or targeting.")
    required("EDG_SOURCE_HEAD")
    required("EDG_SOURCE_TREE")
    project = TOML.parsefile(joinpath(core_directory, "Project.toml"))
    get(project, "name", "") == "SpaceAGORA" &&
        get(project, "uuid", "") == "afbfb69f-5c0b-4832-b760-43725dff8540" || error("EDG_CORE_PATH is not SpaceAGORA.")
    fixture = joinpath(core_directory, fixture_relative)
    isfile(fixture) && filehash(fixture) == fixture_sha256 ||
        error("The private core test fixture differs from this retained recipe. Use the recorded source pair.")
    core_entry = Base.find_package("SpaceAGORA")
    core_entry !== nothing && realpath(dirname(dirname(core_entry))) == core_directory ||
        error("The active benchmark environment must load SpaceAGORA from EDG_CORE_PATH.")
    provider_entry = Base.find_package("SpaceAGORAEDG")
    provider_entry !== nothing && realpath(dirname(dirname(provider_entry))) == realpath(companion_directory) ||
        error("The active benchmark environment must load this companion checkout.")
    for name in ("ComponentArrays", "SPICE", "SpecialFunctions", "StaticArrays")
        Base.find_package(name) === nothing && error("The benchmark environment is missing $name; prepare it with the core test helper.")
    end
    isfile(bridge_library) || error("EDG_NATIVE_LIBRARY must name the compiled lab bridge.")
    isdir(joinpath(gram_assets, "Mars", "data")) || error("Missing authorized Mars/data directory.")
    for kernel in kernels
        path = joinpath(gram_assets, "SPICE", kernel)
        isfile(path) || error("Missing SPICE kernel: $kernel")
        open(path) do io
            startswith(String(read(io, min(64, filesize(path)))), "version https://git-lfs.github.com/spec/") &&
                error("SPICE input is an unmaterialized LFS pointer: $kernel")
        end
    end
    destination = canonical_output(output_directory)
    any(root -> inside(destination, root), (core_directory, companion_directory, gram_assets)) &&
        error("Use a separate output directory outside source and asset trees.")
    isdir(destination) && !isempty(readdir(destination)) && error("Output directory is not empty; preserve it and choose a fresh directory.")
    println("NATIVE_REFERENCE_PREFLIGHT_OK case=", case)
    return nothing
end

function record_inputs()
    files = ("refresh_comparison.jl", "native_direct.jl", "observer_comparison_cases.jl",
        "load_ephemerides.jl", "paths.jl", "native_bridge.cpp", "provenance.json")
    record = Dict("case" => get(ENV, "EDG_CASE", "depletion"),
        "declared_core_head" => required("EDG_SOURCE_HEAD"),
        "declared_core_tree_or_runtime_manifest" => required("EDG_SOURCE_TREE"),
        "core_path" => core_directory, "companion_path" => companion_directory,
        "native_asset_root" => gram_assets, "native_library" => bridge_library,
        "native_library_sha256" => filehash(bridge_library),
        "private_fixture_sha256" => filehash(joinpath(core_directory, fixture_relative)),
        "recipe_sha256" => Dict(file => filehash(joinpath(recipe_directory, file)) for file in files),
        "qualification" => "Path and recipe identities only; native source/data identity, dependency manifest and clean source-pair qualification must be retained separately.")
    open(joinpath(output_directory, "run_inputs.toml"), "w") do io
        TOML.print(io, record; sorted=true)
    end
end
end
