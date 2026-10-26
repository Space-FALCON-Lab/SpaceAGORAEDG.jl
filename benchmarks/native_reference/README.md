# Retained native Mars reference cases

This directory lets you run the retained EDG comparison from the companion
repository. It has the same depletion, fixed-target and two-pass cases that were
used to compare the integrated core with the extracted package. The equations,
initial states, native settings, solver settings and guidance cadence are
unchanged; only the input and output paths and a preflight check were added.

These are narrow experimental comparisons. They do not reproduce all the journal
figures, they are not flight qualification, and they do not show that every
trajectory meets its constraints. The [scientific status](../../docs/scientific_status.md) explains
the accepted scope. Use [the analytic example](../../examples/analytic_atmosphere.jl)
for an installation check that does not require native data.

## Required source pair and inputs

This recipe belongs to the v0.1.0 source pair: the companion's `v0.1.0` tag and the
core revision its `CoreSource.toml` records (`05de98e3463eeb519d5784429ef641012cf0abf4`,
EDG contract 1.0.0). Later core revisions change the fixture it hashes, so it has
not been refreshed since contract 1.0.0. It deliberately uses the private core
fixture `test/gnc/aerobraking/energy_depletion_gnc_tests.jl` and internal
observation hooks, and preflight checks the fixture's exact hash. Those private
names belong to this pinned research recipe and are not part of the public
`EDGServices` interface. A newer fixture needs a new comparison and review.

Check out both repositories at that pair and keep both checkouts available:

```sh
git -C /absolute/path/to/SpaceAGORAEDG.jl checkout v0.1.0
git -C /absolute/path/to/SpaceAGORA.jl checkout 05de98e3463eeb519d5784429ef641012cf0abf4
```

The Julia environment needs the core's scientific dependencies as well as the
companion, including direct access to ComponentArrays and SPICE. With Julia 1.12,
prepare a separate benchmark environment with that core revision's test helper,
which accepts only companion version 0.1.0:

```sh
SPACEAGORA_EDG_PATH=/absolute/path/to/SpaceAGORAEDG.jl \
  julia --startup-file=no --project=@stdlib \
  /absolute/path/to/SpaceAGORA.jl/scripts/setup_edg.jl /absolute/path/to/reference-env
```

The helper seeds the separate environment from the core's manifest and records
both local source paths; it does not modify the tracked core environment. Keep the
resulting manifest with your results. Setting up from local paths does not show
that either working tree is clean or scientifically qualified.

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

NASA source, model data, kernels and compiled libraries are not distributed here;
keep their source identities and file hashes separately. Preflight checks the
paths and rejects kernel files that are still Git LFS pointers; it does not
certify a complete native installation or that the data are equivalent.

## Build the small comparison bridge

`native_bridge.cpp` is the lab-written C interface used for the comparisons,
unchanged. It calls an existing GRAM library and contains no NASA code. The
recorded build used Apple clang 21.0.0, C++11 and macOS arm64. This is the
recorded command with its paths replaced by variables:

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
runtime dependencies must stay at their recorded locations. The GRAM build behind
the comparisons used the available CSPICE static library; follow your authorized
GRAM distribution's build instructions to prepare it, since this recipe does not
build GRAM. Other platforms need the corresponding compiler, shared-library mode
and runtime search paths, and the macOS evidence does not qualify those builds.

## Run one case in a fresh process

Set the paths explicitly and choose a new output directory outside the source
and asset trees; it must not contain earlier results. The two source labels are
recorded as you supply them, so also keep the actual core and companion commits,
the working-tree status and the dependency and asset identities.

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

Preflight does not load native code, load kernels, create outputs or advance the
spacecraft. The second command runs the whole selected case. Use a new process and
a new output directory for each case:

| `EDG_CASE` | Retained case and endpoint |
|---|---|
| `depletion` | Incoming spherical 160 km state, atmospheric passage and coast to the first post-exit apoapsis. |
| `targeting` | The same incoming state, a fixed target apoapsis radius of 19,780,944.9723878 m, replanning, and coast to the actual apoapsis. The target is not adjusted from the resulting trajectory. |
| `two_pass` | Start at the preceding apoapsis, complete two atmospheric passages and stop at the second exit. There is no final coast after that exit. |

The target-selection helper stays in the driver so that its source matches the
original, but none of these commands calls it: all three leave
`select_reachable=false`, so no private baseline CSV is needed.

## Read the results

The driver writes `extracted_<case>.csv`, its TOML diagnostics and partial event
records. `run_inputs.toml` also records the selected paths, the recipe and bridge
hashes, and the private fixture hash. The `extracted_` file names and the
`runtime_source_modified=true` metadata field are kept from the original runs so
the outputs can be compared; that field says nothing about your checkout, so
record its actual state separately. The driver keeps the solver's return code and
diagnostics, and a numerical error makes the process fail. Check the return code
and the expected final event before treating an output as a completed comparison:
a zero exit status alone does not show that the solver reached the intended
endpoint.

The CSV includes planet-centred inertial position and velocity, spherical and
geodetic altitude, native density and temperature, air-relative speed, panel
angle, heat rate, cumulative bus and panel heat, orbital energy, the structural
proxy and the guidance diagnostics. The TOML records the spherical events, the
observed geodetic passage heat, the plans and the apoapses. Phase boundaries are
spherical, while passage heat is counted geodetically.

The settings are 3 Hz guidance and control, a 0.15 W/cm² heat-rate limit, a
30 J/cm² passage heat-load limit and a 0.5 Pa structural proxy limit. The native
bridge uses seed 20261009, perturbation scale 1.5, relative step setting 0.5,
MOLA disabled and epoch 2001-11-06 19:00:00 UTC. The driver reads nominal native
density and temperature, with wind and topography disabled. See
[provenance.json](provenance.json) and the driver for all fixed values.

In the depletion and two-pass comparisons, the integrated and extracted code give
matching trajectories and event and heat records. Their sampled peak panel heat
rates, 0.15137451241766942 and 0.15101616175344842 W/cm², exceed the original
limit and remain violations. Agreement between the two implementations shows
that the packaging kept the results; it does not prove that the constraints are
met. Saved samples do not bound a peak between samples, and the fixed early target
says nothing about accuracy for arbitrary targets or near the heat budget. Running
this recipe does not replace testing and reviewing the exact source pair you
report.
