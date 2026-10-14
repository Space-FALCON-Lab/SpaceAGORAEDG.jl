# Extending a study

Start with a case that runs unchanged in the installed environment. Keep its
configuration and output as a reference before changing the vehicle,
atmosphere or guidance settings. This gives a failed comparison an identifiable
cause and keeps a packaging problem separate from a scientific result.

## Run and inspect the short example

After [installation](installation.md), run from the companion checkout:

```sh
julia --startup-file=no --project=/path/to/edg-env examples/analytic_atmosphere.jl
```

The example propagates a three-body spacecraft for two seconds using an analytic
Earth atmosphere. Its guidance and control share one EDG state and update every
1/3 second. It prints the applied angle, the controller's heat-rate estimate and
dynamic pressure. It is an installation and ownership exercise, not a native-GRAM
case, targeting benchmark or journal reproduction.

To inspect the result in Julia, include the example and call its runner:

```julia
include("examples/analytic_atmosphere.jl")
run = run_analytic_edg()
result = run.result
state = only(result.configuration.control_model.control_effectors).state

state.last_alpha_rad[1]
state.last_heat_rate_w_cm2[1]
state.last_dynamic_pressure_pa[1]
result.table
```

The runner returns both the original configuration and the completed result.
Read the state from `result.configuration`: the default run isolates mutable
state from the original input while preserving the shared guidance/control
relationship inside the run. The heat-rate estimate printed by this example
is not an independent measurement of every propagated panel's thermal load.

## Make one bounded change

The example exposes `duration_s` so the installation walkthrough can be extended
without changing the model, limits or cadence:

```julia
run = run_analytic_edg(; duration_s=3.0)
@assert only(run.result.configuration.control_model.control_effectors).state ===
        only(run.result.configuration.guidance_model.guidance_effectors).state
```

This exercises a longer execution of the same short case. It does not increase
the case's scientific qualification. For a new study, copy the example into your
own project and give it a distinct name. State what you changed and why. Preserve
3 Hz and the original limits when reproducing the accepted comparisons.

Before claiming thermal or structural feasibility, save the relevant propagated
panel quantities over the passage, including between command updates. Label
units, the selected panels, the aggregation and the difference between a
predicted and an executed result. A finite angle or a successful solver return
is not a feasibility test.

## Add models through core interfaces

New atmospheres, force models and outputs belong at SpaceAGORA's documented
model interfaces. See [Add a density model](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/388b8801b3e912c264b04a462b019acbaf1c0d1a/docs/src/extensibility.md#add-a-density-model)
and the [density-model template](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/388b8801b3e912c264b04a462b019acbaf1c0d1a/templates/density_model_template.jl)
for the public `SpaceAGORA.AbstractDensityModel` and `SpaceAGORA.getDensity`
interface, or the [custom-force walkthrough](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/blob/388b8801b3e912c264b04a462b019acbaf1c0d1a/docs/src/user/custom_effector.md)
for a force/torque component. These interface references are pinned to the
upstream base retained by this extraction. Supply models through
`SimulationConfiguration`; the EDG
prediction services then use the configured core queries. Do not reach into
`ODEParams`, replace private core methods or retain a borrowed prediction handle.
Core owns physical propagation and panel actuation.

A change to the EDG algorithm itself belongs in this companion and requires
review of its versioned service inventory, numerical parity and lifecycle
behavior. Run the companion suite, both package load orders, the existing core
EDG regressions and the relevant native comparisons. Retain a failing example
as evidence rather than changing scientific thresholds merely to make it pass.
The [compatibility guide](compatibility.md) defines the supported boundary;
[Scientific status](scientific_status.md) describes what those checks can and
cannot establish.

## Run the companion checks

From the companion checkout with the installed paired environment:

```sh
julia --startup-file=no test/installation_tests.jl
julia --startup-file=no --project=/path/to/edg-env -e 'using Pkg; Pkg.test("SpaceAGORAEDG")'
```

The [CI workflow](../.github/workflows/ci.yml) installs the recorded public pair,
runs these checks and exercises both package load orders. The core repository
also runs its existing EDG numerical, lifecycle, native and coverage suites with
the selected provider. Passing the companion suite alone does not replace those
checks or the native scientific comparisons.
