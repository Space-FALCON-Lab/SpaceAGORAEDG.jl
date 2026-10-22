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
Construct guidance and control with the same configuration and the **same state
object**. Two independently constructed, initially equal state objects do not
share subsequent decisions. The state has one entry per spacecraft.

`controlled_panel_links` identifies links inside each spacecraft. Selected links
must be rotatable non-root links supported by the core panel controller. A panel
on a moving articulated body is outside the supported kinematic EDG route; this
package does not supply a joint motor, actuator rate limit or attitude controller.

Set guidance and control periods to `1 / 3` seconds for the qualified 3 Hz
comparison. In SpaceAGORA, `guidance_rates` and `control_rates` hold periods in
seconds despite their names. Commands remain held between updates. Faster
updates, added safety margins or relaxed limits define a different experiment.

The physical limits default to `Inf`. Selecting a restriction with an infinite
threshold does not establish finite protection. Use the documented case's
limits for a reproduction, or explicitly state and justify new limits for a
new study.

## Follow the ownership boundary

SpaceAGORA prepares a copied observation of the relevant physical state and
provides call-scoped access to its atmosphere, gravity, frame and control-clock
services. SpaceAGORAEDG computes guidance and control decisions. Core then
applies the command to the selected panels and propagates the physical state.
An extension never receives the mutable engine parameter object as a supported
public argument.

During a run, guidance owns the targeting plan and its replanning clock. When
guidance and control are due together, guidance runs first and control consumes
the plan. Control does not independently advance the targeting replan clock.
Passage transitions invalidate only the affected spacecraft's cached plan.
Physical heat integrals continue accumulating.

A normal `run_simulation` starts a fresh EDG runtime. Default configuration
isolation preserves the shared guidance/control state inside the run while
separating it from the caller's original configuration. Read completed
diagnostics from `result.configuration` when using
`run_simulation(args; return_results=true)`. The caller's original state is not
the completed isolated run. EDG checkpoint writing and resume remain unsupported.

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
are distinct calculations. Assess heating with the saved thermal quantities on
the controlled panels as well as the guidance diagnostics. A whole-spacecraft
maximum may include the bus; label the panel set and aggregation used.

Save applied angle, mode, switch diagnostics, heat rates and heat loads together
with time, position, velocity and density. Re-evaluating an earlier state with
the panels' final orientation does not reconstruct the forces and heat that
were applied during propagation.

A low-drag fallback describes a command policy. It is not proof of feasibility.
An unreachable target, an invalid sampled candidate family, an empty structural
admissible set and a measured constraint violation are different outcomes and
should remain distinguishable in the report.

Continue with [Extending a study](extension_guide.md) to run the short
analytic-atmosphere example, inspect its diagnostics and change one study
assumption at a time. The [scientific-status guide](scientific_status.md) explains
which conclusions the retained examples support.
