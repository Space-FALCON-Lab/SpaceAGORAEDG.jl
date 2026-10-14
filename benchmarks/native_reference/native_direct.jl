using Libdl
const EM=SM.EnvironmentModels
const native_library=NativeReferencePaths.bridge_library
const native_assets=NativeReferencePaths.gram_assets
const native_context=ccall((:edg_gram_create,native_library),Ptr{Cvoid},(Cstring,Cstring),joinpath(native_assets,"Mars/data/"),joinpath(native_assets,"SPICE"))
native_context==C_NULL && error(unsafe_string(ccall((:edg_gram_error,native_library),Cstring,())))
const native_calls=Ref(0);const native_requests=Ref(0);const native_cache_hits=Ref(0);const native_checked_hits=Ref(0)
const native_cache=Dict{NTuple{4,Float64},Tuple{Float64,Float64}}()
const native_output=zeros(2)
function native_query(key)
 status=ccall((:edg_gram_query,native_library),Cint,(Ptr{Cvoid},Cdouble,Cdouble,Cdouble,Cdouble,Ptr{Cdouble}),native_context,key[1],key[2],key[3],key[4],native_output)
 status==0 || error(unsafe_string(ccall((:edg_gram_error,native_library),Cstring,())))
 native_calls[]+=1
 result=(native_output[1],native_output[2])
 @assert isfinite(result[1]) && result[1]>=0 && isfinite(result[2]) && result[2]>0
 return result
end
struct NativeComparisonAtmosphere <: SM.AbstractDensityModel end
function EM.getDensity(::NativeComparisonAtmosphere,h::Float64,lat::Float64,lon::Float64,t::Float64,wind::Bool,p)
 @assert !p.args.environment_model.wind
 h>160000.0 && return 0.0,150.0,SVector{3,Float64}(0.0,0.0,0.0)
 key=(h*1e-3,rad2deg(lat),rad2deg(lon),t);native_requests[]+=1
 if haskey(native_cache,key)
  value=native_cache[key];native_cache_hits[]+=1
  if native_cache_hits[]%10000==0
   @assert native_query(key)==value "Native nominal result changed across repeated exact-coordinate query"
   native_checked_hits[]+=1
  end
 else
  value=native_query(key)
  length(native_cache)>=250000 && empty!(native_cache)
  native_cache[key]=value
 end
 if native_requests[]%1000000==0
  println("NATIVE_PROGRESS requests=",native_requests[]," actual=",native_calls[]," exact_cache_hits=",native_cache_hits[]," wall=",now());flush(stdout)
 end
 return value[1],value[2],SVector{3,Float64}(0.0,0.0,0.0)
end
println("DIRECT_NATIVE_READY exact_key_cache_bound=250000");flush(stdout)
