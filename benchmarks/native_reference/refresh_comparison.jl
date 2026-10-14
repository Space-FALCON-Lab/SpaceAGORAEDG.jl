Base.exit_on_sigint(false)
using Dates, TOML, Test
include(joinpath(@__DIR__, "paths.jl"))
const ROOT=NativeReferencePaths.output_directory
const REPO_ROOT=NativeReferencePaths.core_directory
NativeReferencePaths.preflight()
mkpath(ROOT)
NativeReferencePaths.record_inputs()
println("MODEL_LOAD ",now());flush(stdout)
using SpaceAGORAEDG
using SpaceAGORA, LinearAlgebra, StaticArrays, ComponentArrays
const SimulationModel=SpaceAGORA.SimulationModel
const SimulationEngine=SpaceAGORA.SimulationEngine
const SM=SimulationModel;const CH=SM.ControlHooks
include(joinpath(@__DIR__,"load_ephemerides.jl"))
function save_result(name,d)
 open(joinpath(ROOT,name*".toml"),"w") do io;TOML.print(io,d);end
end
println("MODEL_READY ",now());flush(stdout)
source=read(joinpath(REPO_ROOT,"test/gnc/aerobraking/energy_depletion_gnc_tests.jl"),String)
include_string(Main,first(split(source,"@testset")))
include(joinpath(@__DIR__,"native_direct.jl"))
include(joinpath(@__DIR__,"observer_comparison_cases.jl"))
case=get(ENV,"EDG_CASE","depletion")
if case=="targeting"
 run_comparison("extracted_targeting";targeting=true,target_radius=19780944.9723878,select_reachable=false)
elseif case=="two_pass"
 run_comparison("extracted_two_pass";two_pass=true)
else
 run_comparison("extracted_depletion")
end
println("FINAL_NATIVE_COMPARISON_COMPLETE ",now());flush(stdout)
