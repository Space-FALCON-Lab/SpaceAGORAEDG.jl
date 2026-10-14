# Retained native Mars reference cases

This directory makes the retained EDG comparison executable from the companion
repository. It contains the same depletion, fixed-target and two-pass cases used
to compare the integrated core with the extracted package. The equations, initial
states, native settings, solver settings and guidance cadence are unchanged.
Only input/output paths and a preflight check have been added.

These are narrow experimental comparisons. They are not reproductions of all
journal figures, flight qualification or evidence that every trajectory satisfies
its constraints. The [scientific status](../../docs/scientific_status.md) explains
the accepted scope. Use [the analytic example](../../examples/analytic_atmosphere.jl)
for an installation check that does not require native data.

## Required source pair and inputs

Use the core revision recorded in this companion's [CoreSource.toml](../../CoreSource.toml)
and the companion revision recorded by the qualified parent. Both checkouts must
remain available. This benchmark deliberately consumes the private core fixture
`test/gnc/aerobraking/energy_depletion_gnc_tests.jl` and internal observation hooks.
Preflight checks the fixture's exact hash. These private names belong to this
pinned research recipe; they are not additions to the public `EDGServices` API.
A newer fixture requires a new comparison and review.

The Julia environment needs the core's scientific dependencies as well as the
companion, including direct access to ComponentArrays and SPICE. With Julia 1.12,
prepare a separate benchmark environment from the identified checkouts:

```sh
SPACEAGORA_EDG_PATH=/absolute/path/to/SpaceAGORAEDG.jl \
  julia --startup-file=no --project=@stdlib \
  /absolute/path/to/SpaceAGORA.jl/scripts/setup_edg.jl /absolute/path/to/reference-env
```

This test helper seeds the separate environment from the core's Manifest and
records both local source paths. It does not modify the tracked core environment.
Retain the resulting Manifest with your results. Local-path setup itself does
not establish that either working tree is clean or scientifically qualified.

You also need authorized NASA GRAM 2.0 source and Mars data, a compatible built
GRAM library, and these five materialized SPICE kernels under an asset root:

```text
GRAM-assets/
├── Mars/data/
└── SPICE/
    ├── pck/pck00011.tpc
    ├── lsk/naif0012.tls
    ├── spk/planets/de440_GRAM.bsp
    ├── spk/planets/de440s.bsp
    └── spk/satellites/sat441_GRAM.bsp
```

NASA source, model data, kernels and compiled libraries are not distributed here.
Retain their source identities and file hashes separately. Preflight checks the
paths and rejects unmaterialized kernel pointers; it does not certify a complete
native installation or establish data equivalence.

## Build the small comparison bridge

`native_bridge.cpp` is the retained lab-written C interface, unchanged from the
qualified local bridge. It calls an existing GRAM library; it contains no NASA
implementation. The recorded build used Apple clang 21.0.0, C++11 and macOS arm64.
The following command is the retained command with its paths parameterized:

```sh
export GRAM_NATIVE_SOURCE=/absolute/path/to/authorized/GRAM-source
export EDG_NATIVE_LIBRARY=/absolute/path/to/separate-build/native_bridge.dylib
mkdir -p "$(dirname "$EDG_NATIVE_LIBRARY")"
/usr/bin/clang++ -std=c++11 -dynamiclib \
  -I"$GRAM_NATIVE_SOURCE/Mars/include" \
  -I"$GRAM_NATIVE_SOURCE/common/include" \
  benchmarks/native_reference/native_bridge.cpp \
  "$GRAM_NATIVE_SOURCE/Build/lib/libGRAM.dylib" \
  -Wl,-rpath,"$GRAM_NATIVE_SOURCE/Build/lib" \
  -o "$EDG_NATIVE_LIBRARY"
```

Run that command from the companion checkout. The linked GRAM library and its
runtime dependencies must remain available at their recorded locations. The
underlying retained GRAM build used the available CSPICE static library. Follow
your authorized GRAM distribution's build instructions to prepare it; this recipe
does not rebuild GRAM. Other platforms need the corresponding compiler, shared
library mode and runtime search paths. Their bridge builds are not qualified by
the macOS evidence.

## Run one case in a fresh process

Set the paths explicitly and choose a fresh output directory outside the source
and asset trees. The directory may not contain existing results. The two source
labels are recorded as supplied; keep the actual core and companion commits,
working-tree status and dependency/asset identities alongside them.

```sh
export EDG_CORE_PATH=/absolute/path/to/SpaceAGORA.jl
export EDG_GRAM_ASSET_ROOT=/absolute/path/to/GRAM-assets
export EDG_NATIVE_LIBRARY=/absolute/path/to/separate-build/native_bridge.dylib
export EDG_OUTPUT_DIR=/absolute/path/to/new-reference-results
export EDG_SOURCE_HEAD="$(git -C "$EDG_CORE_PATH" rev-parse HEAD)"
export EDG_SOURCE_TREE="$(git -C "$EDG_CORE_PATH" rev-parse 'HEAD^{tree}')"
export EDG_CASE=depletion
export JULIA_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

julia --startup-file=no --project=/absolute/path/to/reference-env \
  benchmarks/native_reference/preflight.jl
julia --threads=1 --compiled-modules=existing --startup-file=no --history-file=no \
  --project=/absolute/path/to/reference-env \
  benchmarks/native_reference/refresh_comparison.jl
```

Preflight does not load native code, furnish kernels, create outputs or advance
the spacecraft. The second command runs the complete selected case. Use a new
process and output directory for each case:

| `EDG_CASE` | Retained case and endpoint |
|---|---|
| `depletion` | Incoming spherical 160 km state, atmospheric passage and coast to the first post-exit apoapsis. |
| `targeting` | The same incoming state, fixed prospective apoapsis radius **19,780,944.9723878 m**, replanning and coast to actual apoapsis. The target is not adjusted from the resulting trajectory. |
| `two_pass` | Start at the preceding apoapsis, complete two atmospheric passages and stop at the second exit. There is no final coast after that exit. |

The target-selection helper remains in the retained driver for source parity,
but none of these commands calls it. All three command routes leave
`select_reachable=false`; no private baseline CSV is needed to run them.

## Read the results

The driver writes `extracted_<case>.csv`, its TOML diagnostics and partial event
records. `run_inputs.toml` additionally records selected paths, recipe and bridge
hashes, and the private fixture hash. The old `extracted_` filenames and historical
`runtime_source_modified=true` metadata field are preserved for comparison
compatibility. That field is not a fresh assessment of your checkout; record its
actual status separately. The driver preserves the solver return code and
diagnostics; a thrown numerical error produces a failed process status. Check
the return code and the expected final event before treating an output as a
completed comparison. A zero process status alone does not establish that the
solver reached the intended endpoint.

The CSV includes PCI position/velocity, spherical and geodetic altitude, native
density and temperature, air-relative speed, panel angle, heat rate, cumulative
bus/panel heat, orbital energy, structural proxy and guidance diagnostics. The
TOML records spherical events, observed geodetic passage heat, plans and apoapses.
Spherical phase boundaries and geodetic passage accounting are distinct.

The retained settings are 3 Hz guidance and control, heat-rate limit 0.15 W/cm²,
passage heat-load limit 30 J/cm² and structural proxy limit 0.5 Pa. The native
bridge retains seed 20261009, perturbation scale 1.5, relative step setting 0.5,
MOLA disabled and epoch 2001-11-06 19:00:00 UTC. The driver reads nominal native
density and temperature, with wind and topography disabled. See
[provenance.json](provenance.json) and the unchanged driver for all fixed values.

The retained integrated/extracted depletion and two-pass comparisons have matching
trajectories and event/heat records. Their sampled peak panel heat rates remain
0.15137451241766942 and 0.15101616175344842 W/cm². Both exceed the original limit
and remain violations. Agreement between implementations is a packaging/parity
result, not proof of constraint satisfaction. Saved samples do not bound an
unobserved continuous-time peak. The fixed early target does not establish
arbitrary-target or near-budget accuracy; the public recipe itself does not
substitute for final-pair execution and review.
