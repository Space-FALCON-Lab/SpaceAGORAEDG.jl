using SPICE
for kernel in ["pck/pck00011.tpc","spk/planets/de440_GRAM.bsp","lsk/naif0012.tls","spk/planets/de440s.bsp","spk/satellites/sat441_GRAM.bsp"]
 SPICE.furnsh(joinpath(NativeReferencePaths.gram_assets,"SPICE",kernel))
end
println("EPHEMERIDES_READY")
