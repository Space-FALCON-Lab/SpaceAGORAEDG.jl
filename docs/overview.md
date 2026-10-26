# How EDG fits into a mission

Energy-depletion guidance changes the angle of selected panels during an
atmospheric passage. Their changing exposure changes drag and heating. A
maximum-depletion case seeks to remove energy within the modeled restrictions;
a targeting case compares executable candidate commands with a specified
apoapsis radius. These are guidance objectives, not a guarantee that the
propagated trajectory is feasible or globally optimal.

## Configure one shared runtime

First follow [Installation](installation.md) to prepare the paired environment.
Start Julia with `julia --project=/path/to/edg-env`, using the destination you
chose during setup, then load both packages:

```julia
using SpaceAGORA
using SpaceAGORAEDG
```

The public `AerobrakingEnergyDepletionConfig`,
`AerobrakingEnergyDepletionState`,
`AerobrakingEnergyDepletionGuidanceModel` and
`AerobrakingEnergyDepletionControlModel` types still belong to SpaceAGORA.
Construct guidance and control with the same configuration and the same state
object. Two state objects built separately do not share later decisions, even if
they start equal. The state has one entry per spacecraft.

`controlled_panel_links` names links inside each spacecraft. They must be
rotatable non-root links that the core panel controller supports. A panel on a
moving articulated body is not supported: this package supplies no joint motor,
actuator rate limit or attitude controller.

Set the guidance and control periods to `1 / 3` seconds to match the 3 Hz
comparisons. Despite their names, SpaceAGORA's `guidance_rates` and
`control_rates` hold periods in seconds. Commands are held between updates.
Faster updates, added safety margins or relaxed limits make a different
experiment.

The physical limits default to `Inf`, and a restriction with an infinite
threshold protects nothing. Use the documented case's limits to reproduce it, or
state and justify new limits for a new study.

## Follow the ownership boundary

SpaceAGORA prepares a copy of the relevant physical state and gives each call
temporary access to its atmosphere, gravity, frame and control-clock services.
SpaceAGORAEDG computes the guidance and control decisions. SpaceAGORA then applies
the command to the selected panels and propagates the physical state. The
companion never receives the engine's mutable parameter object as a supported
argument.

During a run, guidance owns the targeting plan and its replanning clock. When
guidance and control are due at the same time, guidance runs first and control
uses the plan; control never advances the replanning clock itself. A passage
transition invalidates only the affected spacecraft's cached plan, and the
physical heat integrals keep accumulating.

A normal `run_simulation` starts a fresh EDG runtime. By default the run works
on an isolated copy of the configuration: guidance and control still share one
state inside the run, but your original configuration is left as it was. With
`run_simulation(args; return_results=true)`, read the final diagnostics from
`result.configuration`, not from your original state object. Writing checkpoints
and resuming are not supported with EDG.

## Read units and diagnostics carefully

| Quantity | Meaning and unit |
|---|---|
| `target_apoapsis_radius_m` | Radius from the planet's centre in metres, not altitude. |
| Specific orbital energy | Inertial two-body diagnostic in J/kg. Other enabled perturbations can also change it. |
| Airspeed | Spacecraft velocity relative to the rotating planet minus atmospheric wind, in m/s. |
| Panel angle | Radians. |
| Heat rate | W/cm². |
| Heat load | J/cm², the time integral of heat rate. |
| Passage heat | Maximum of the controlled panels' individual increments since geodetic entry. |
| `structural_load_limit_pa` | Pressure-valued setting for a drag-based force proxy, not a finite-element stress limit. |

Passage heat is formed by subtracting each panel's own entry baseline from that
panel's current integral. Subtracting the maximum baseline from the maximum
current heat can mix two different panels and give the wrong quantity.
`last_heat_load_j_cm2` remains cumulative telemetry;
`last_pass_heat_load_j_cm2` is the passage quantity used by planning.

The controller's internal heat-rate estimate and the propagated thermal model
are separate calculations. Assess heating with the saved thermal quantities on
the controlled panels as well as the guidance diagnostics. A whole-spacecraft
maximum may include the bus, so say which panels and which aggregation you used.

Save applied angle, mode, switch diagnostics, heat rates and heat loads together
with time, position, velocity and density. Re-evaluating an earlier state with
the panels' final orientation does not reconstruct the forces and heat that
were applied during propagation.

A low-drag fallback is a command policy, not proof of feasibility. An unreachable
target, an invalid sampled candidate family, an empty structurally admissible set
and a measured constraint violation are different outcomes; keep them apart in a
report.

Continue with [Extending a study](extension_guide.md) to run the short
analytic-atmosphere example, inspect its diagnostics and change one study
assumption at a time. The [scientific-status guide](scientific_status.md) explains
which conclusions the retained examples support.
