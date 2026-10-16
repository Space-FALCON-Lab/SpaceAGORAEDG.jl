# Compatibility and ownership

Use the exact core and companion revisions recorded for the release. The
companion requires Julia 1.12, SpaceAGORA 0.2 and **EDGServices contract 1.0.0**.
The broad package version constraint alone does not identify a qualified source
pair. `CoreSource.toml` records the core revision used by the standalone
installer; SpaceAGORA's optional-package gitlink records its companion revision.

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

Core loads without this companion for non-EDG missions. Selecting EDG without
loading the provider raises `EDGUnavailableError` before output creation or
stepping. It does not substitute a different guidance law. If a contract check
fails, install the identified pair and start a fresh Julia process; do not try to
repair an already partially loaded session by redefining methods.

## The public boundary

The facade is `SpaceAGORA.EDGServices`. Its explicit implementation inventory
contains `guidance_decision!` and `control_decision!`; its consumed-service
inventory names the values and query operations used by this companion. Public
configuration, state, model and `AerobrakingControlCommand` identities remain
in core. `EDGControlDecision` carries the command, whether to apply it, the
switch/cache action and copied diagnostics.

The observation copies inertial position, velocity, mass and cumulative panel
heat into scalar values, immutable vectors and tuples. Geometry queries likewise
return copied dimensions, areas, masses, reflection coefficients and angles.
The provider may update the run-owned EDG plan and diagnostic state. It may not
write the simulator's physical state or vehicle geometry.

Prediction queries use an opaque, synchronous capability whose lifetime ends
when its enclosing algorithm call returns, including on an exception. A retained
handle cannot be reused later. Ordinary property access is refused. Julia
reflection into private fields is outside the supported contract; this is an
ownership interface, not a security sandbox.

Atmosphere and frame services retain their existing conventions: elapsed time
for atmosphere queries, configured epoch plus elapsed time for frame queries,
and spacecraft-minus-wind air-relative velocity. Atmosphere cache and random
number behavior remain core-owned. The extraction does not silently reseed a
model or create a different prediction atmosphere.

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

SpaceAGORA removed its older E-EDG and T-EDG strategy routes
([PR #352](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/pull/352)). Shared
typed numerical helpers in core forward to this package, so a helper name in
core is not a second implementation. Private compatibility helper names support
existing callers and tests; they are not a general extension API.

A change to equations, limits, timing, frame conventions, atmosphere query
semantics or state ownership needs its own review and comparison evidence.
A version-compatible load and passing installation test cannot supply that
scientific evidence.
