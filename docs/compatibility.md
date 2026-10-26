# Compatibility and ownership

Use a core and companion pair that were tested together. The current `main`
admits Julia 1.12, SpaceAGORA 0.6 and 0.7, and `EDGServices` contract 3.0.0; its
default core pin is SpaceAGORA v0.7.0. The `v0.5.1` tag predates the 0.7 support
and admits SpaceAGORA 0.6 only. A version range alone does not identify a tested
pair: `CoreSource.toml` records the core revision for the standalone installer,
and SpaceAGORA's optional-package submodule records the companion revision for
each SpaceAGORA release (commit `424d8aa8` for v0.7.1).

Both load orders are supported:

```julia
using SpaceAGORA
using SpaceAGORAEDG
```

or, in a fresh process:

```julia
using SpaceAGORAEDG
using SpaceAGORA
```

The core loads without this companion for missions that do not use EDG.
Selecting EDG without loading the provider raises `EDGUnavailableError` before any
output is created or any step is taken; the core does not substitute another
guidance law. `test/load_order.jl` checks both load orders and this refusal in
fresh processes, and `test/service_boundary.jl` checks that the package uses only
the names the `EDGServices` contract lists, including through local aliases and
inside function bodies. If a contract check fails, install a matching pair and
start a fresh Julia process; do not try to repair a partly loaded session by
redefining methods.

## The public boundary

The interface is `SpaceAGORA.EDGServices`. The companion implements its two
decision services, which take the run's EDG state first:
`guidance_decision!(state, config, u, p, t, spacecraft_index)` and
`control_decision!(state, config, controlled_panel_links, u, p, t,
spacecraft_index)`. The interface also lists the values and queries the
companion uses; every query takes the prediction context `p` first, as in
`_edg_environment_state(p, u, t, spacecraft_index)`. The targeting predictions
read the control clock with `_edg_targeting_control_clock(p)`: the period and
origin of the EDG control ticks that SpaceAGORA reported to the EDG state of the
current call. The public configuration, state and model types and
`AerobrakingControlCommand` stay in the core. An `EDGControlDecision` carries the
command, whether to apply it, the switch and cache action, and copied
diagnostics.

The observation copies the inertial position, velocity, mass and cumulative
panel heat into scalars, immutable vectors and tuples. Geometry queries likewise
return copies of dimensions, areas, masses, reflection coefficients and angles.
The companion may update the EDG plan and diagnostic state that belong to the
run, but not the simulator's physical state or the vehicle geometry.

Prediction queries go through an opaque handle that is valid only until the
algorithm call that received it returns, including when it returns by an
exception; a kept handle cannot be used later, and ordinary property access on it
is refused. Reaching into its private fields by reflection is outside the
supported contract: this is an ownership interface, not a security sandbox.

The atmosphere and frame services keep their conventions: elapsed time for
atmosphere queries, the configured epoch plus elapsed time for frame queries, and
air-relative velocity as spacecraft velocity minus wind. The atmosphere cache and
random numbers stay with the core; the companion does not reseed a model or build
a separate prediction atmosphere.

## Supported use and limits

| Use | Status |
|---|---|
| Paired typed EDG guidance and control with shared per-run state | Supported software route. |
| Maximum-depletion control alone | Retains core's existing initialization and ownership checks. |
| Candidate-specific closed-form targeting | Experimental, qualified only within the documented case scope. |
| Numerical shooting route | Experimental compatibility/reference work. |
| Fresh and repeated isolated runs | Fresh EDG initialization; no implicit continuation. |
| Checkpoint writing or resume with EDG | Refused; complete EDG history is not persisted for continuation. |
| Panels on moving articulated bodies | Outside the supported kinematic panel-control route. |
| Arbitrary-target accuracy, continuous feasibility, real-time throughput | Not established by this release. |

SpaceAGORA 0.3.0 removed the older E-EDG and T-EDG strategy routes from the
core. Since SpaceAGORA 0.6.1 the core forwards only the two decision services to
this package; it no longer forwards the numerical helpers, so there is no second
implementation in the core.

A change to the equations, limits, timing, frame conventions, the meaning of
atmosphere queries or state ownership needs its own review and comparison
evidence. A package that loads and passes the installation tests does not
provide that scientific evidence.
