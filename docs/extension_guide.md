# Extending a study

Start with a case that runs unchanged in the installed environment, and keep its
configuration and output as a reference before changing the vehicle, atmosphere
or guidance settings. Then a failed comparison has a cause you can find, and a
packaging problem stays separate from a scientific result.

## Run and inspect the short example

After [installation](installation.md), run from the companion checkout:

```sh
julia --startup-file=no --project=/path/to/edg-env examples/analytic_atmosphere.jl
```

The example propagates a three-body spacecraft for two seconds in an analytic
Earth atmosphere. Its guidance and control share one EDG state and update every
1/3 second. It prints the applied angle, the controller's heat-rate estimate and
the dynamic pressure. It checks the installation and the ownership boundary; it
is not a native-GRAM case, a targeting benchmark or a reproduction of the journal
results.

To inspect the result, start Julia in the companion checkout with
`--project=/path/to/edg-env`, include the example and call its runner:

```julia
include("examples/analytic_atmosphere.jl")
example = run_analytic_edg()
result = example.result
state = only(result.configuration.control_model.control_effectors).state

state.last_alpha_rad[1]
state.last_heat_rate_w_cm2[1]
state.last_dynamic_pressure_pa[1]
result.table
```

The runner returns both the original configuration and the completed result.
Read the state from `result.configuration`: by default the run works on an
isolated copy, in which guidance and control still share one state, and leaves the
original input unchanged. The heat-rate estimate the example prints is the
controller's estimate, not a measurement of each propagated panel's thermal load.

The example keeps its output in memory: `results=false` turns off result files
and `generate_plots=false` turns off plots. `result.table.time` holds the saved
elapsed times in seconds. This short run saves only its start and its requested
end, so the two rows do not show every solver step or controller update. A normal
return with a final saved time of 2 seconds means this small example completed,
not that an atmospheric passage did.

The `sc1_pos_*` and `sc1_vel_*` columns hold the inertial position in metres and
velocity in metres per second; the configured epoch is 1 January 2024. The
`sc1_heat_rate` and `sc1_heat_load` columns are propagated thermal summaries for
the whole spacecraft and may include the bus. They are neither the controller
estimate the example prints nor a history of the controlled panels alone. See
SpaceAGORA's [output-column reference](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/bec28fcc348b48c6e807d007f9a5009e253e8340/docs/src/user/output_columns.md)
for units and aggregation. Keep the configuration and the exact package revisions
with any saved table; the table alone does not identify the model or the source.

## Make one bounded change

The example takes a `duration_s` keyword, so you can run it longer without
changing the model, the limits or the cadence:

```julia
example = run_analytic_edg(; duration_s=3.0)
@assert only(example.result.configuration.control_model.control_effectors).state ===
        only(example.result.configuration.guidance_model.guidance_effectors).state
```

This runs the same short case for longer; it does not make the case
scientifically stronger. For a new study, copy the example into your own project,
give it its own name, and record what you changed and why. Keep 3 Hz and the
original limits when reproducing the published comparisons.

Before claiming thermal or structural feasibility, save the relevant propagated
panel quantities over the whole passage, including between command updates.
Label the units, the selected panels and the aggregation, and keep predicted and
executed results apart. A finite angle or a successful solver return is not a
feasibility test.

## Add models through core interfaces

New atmospheres, force models and outputs belong at SpaceAGORA's documented
model interfaces. See [Add a density model](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/bec28fcc348b48c6e807d007f9a5009e253e8340/docs/src/extensibility.md#add-a-density-model)
and the [density-model template](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/bec28fcc348b48c6e807d007f9a5009e253e8340/templates/density_model_template.jl)
for the public `SpaceAGORA.AbstractDensityModel` and `SpaceAGORA.getDensity`
interface, or the [custom-force walkthrough](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/bec28fcc348b48c6e807d007f9a5009e253e8340/docs/src/user/custom_effector.md)
for a force or torque component. These links point at the core revision recorded
in `CoreSource.toml` (SpaceAGORA v0.7.0). Supply models through
`SimulationConfiguration`; the EDG prediction services then use the configured
core queries. Do not reach into `ODEParams`, replace private core methods or keep
a borrowed prediction handle. The core owns physical propagation and panel
actuation.

A change to the EDG algorithm itself belongs in this companion, and needs a
review of the service interface it uses, of numerical agreement with the previous
version and of the run lifecycle. Run the companion suite, both load orders, the
core's EDG regressions and the relevant native comparisons. Keep a failing
example as evidence; do not change scientific thresholds just to make it pass.
The [compatibility guide](compatibility.md) defines the supported boundary, and
[Scientific status](scientific_status.md) describes what these checks can and
cannot show.

## Run the companion checks

From the companion checkout, with the installed environment:

```sh
julia --startup-file=no test/installation_tests.jl
julia --startup-file=no --project=/path/to/edg-env -e 'using Pkg; Pkg.test("SpaceAGORAEDG")'
julia --startup-file=no --project=/path/to/edg-env test/incompatible_core.jl
julia --startup-file=no --project=/path/to/edg-env test/load_order.jl core-first
julia --startup-file=no --project=/path/to/edg-env test/load_order.jl edg-first
```

These are the checks of the required `installation-and-contract` job in the
[CI workflow](../.github/workflows/ci.yml), which installs the core recorded in
`CoreSource.toml` with the checkout under test, resolving dependencies afresh.
The separate `contributor-contract` job repeats the suite and the load-order
checks in an environment seeded from the core's manifest (see
[Installation](installation.md#continuous-integration)). The core repository
also runs its existing EDG numerical, lifecycle, native and coverage suites with
the selected provider. Passing the companion suite alone does not replace those
checks or the native scientific comparisons.

## Prediction result assembly

The targeting and maximum-energy prediction strategies share
`_edg_prediction_track` for converting already-integrated samples into returned
trajectory fields. Integration, alpha selection and guidance/control-clock
updates remain in each strategy. The helper preserves sample order and derives
altitude, atmospheric state, speed and flight-path angle using the same service
queries. Targeting tests exercise both strategies with off-clock initial and final
samples, including their distinct interior alpha choices.
