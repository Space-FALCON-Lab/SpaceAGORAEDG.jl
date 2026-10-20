# SpaceAGORAEDG.jl

SpaceAGORAEDG provides experimental energy-depletion guidance for aerobraking
simulations in [SpaceAGORA](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl).
It chooses commands for selected spacecraft panels to remove orbital energy
or approach an apoapsis target while evaluating modeled heating and structural
constraints. SpaceAGORA propagates the spacecraft, evaluates the environment,
and applies the panel commands.

This is an independently installed companion package. Its numerical guidance
implementation lives here; the shared configuration types, simulation lifecycle
and physical state remain in SpaceAGORA. The connection uses the versioned
`SpaceAGORA.EDGServices` interface and Julia's package-extension mechanism.

**The scientific scope is experimental.** The qualified comparison cadence is
3 Hz. Original physical limits are retained, and measured exceedances are
reported as violations. The implementation does not establish universal
constraint satisfaction or exact reproduction of the journal results. Read
[Scientific status](docs/scientific_status.md) before interpreting a run.

## Start here

1. Follow [Installation](docs/installation.md) to create an environment with the
   identified core and companion pair. Julia 1.12 is required.
2. Read [How EDG works](docs/overview.md) to understand configuration, ownership,
   units and the meaning of the saved diagnostics.
3. Run the [analytic-atmosphere example](examples/analytic_atmosphere.jl) and consult
   the [compatibility guide](docs/compatibility.md) when integrating it into a mission.
4. Use [Extending a study](docs/extension_guide.md) to change a case while preserving
   a comparison you can interpret.

The [validation record](docs/validation.md) identifies the tested source,
native comparisons and independent agent walkthroughs, including their limits.

Installing this package does not provide NASA GRAM model data. Native-GRAM
studies require separately available, authorized model data. The standard
SpaceAGORA atmosphere route uses a configured GRAMSuite installation; the retained
comparison recipe below uses its documented lab bridge directly. Synthetic or
frozen-atmosphere examples should be
identified as such; they do not qualify a native atmosphere campaign.

The [native reference cases](benchmarks/native_reference/README.md) provide the
retained depletion, fixed-target and two-pass comparison recipe. They require
authorized native inputs and use a pinned research fixture; they are separate
from the public extension interface.

## What is included

The package owns heat-rate and heat-load planning, the structural-load proxy,
candidate-specific targeting, passage-heat calculations and the numerical
selection of a panel command. The core adapter retains public type identities
and calls these algorithms through copied observations and scoped queries.
There is one active numerical implementation.

SpaceAGORA continues to own the integrator, physical heat integrals, atmosphere
and frame services, callback ordering and panel actuation. The companion does
not advance or replace the simulator’s physical state or reset physical heat. SpaceAGORA
removed the older E-EDG and T-EDG strategy routes in
[SpaceAGORA PR #352](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/pull/352); from
that change on, this package is the only EDG implementation.

Version 0.2.0 implements `EDGServices` contract 2.0.0, whose decision services take
the run's EDG state before the configuration. Version 0.3.0 keeps that contract and
requires SpaceAGORA 0.3 or 0.4; version 0.4.0 keeps it too and requires SpaceAGORA
0.4 or 0.5. The published v0.1.0 release implements contract 1.0.0 with its own
pinned core.

## Publications and license

The original formulation is Falcone and Putnam's *Energy Depletion Guidance for
Aerobraking Atmospheric Passes* (2022). The generalized formulation is Simha,
Yu and Falcone's *Generalized Energy Depletion Guidance for Aerobraking at Mars,
Venus, Earth, and Titan* (2026). [References and current limitations](docs/scientific_status.md)
explain how these relate to the implementation.

This package is distributed under the [MIT license](LICENSE). See
[Source and scientific attribution](NOTICE.md) for provenance.
