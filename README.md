# SpaceAGORAEDG.jl

SpaceAGORAEDG provides experimental energy-depletion guidance for aerobraking
simulations in [SpaceAGORA](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl).
It chooses commands for selected spacecraft panels to remove orbital energy
or approach an apoapsis target while evaluating modeled heating and structural
constraints. SpaceAGORA propagates the spacecraft, evaluates the environment,
and applies the panel commands.

This is a separately installed companion package. The numerical guidance lives
here; the shared configuration types, the simulation lifecycle and the physical
state stay in SpaceAGORA. The two connect through the versioned
`SpaceAGORA.EDGServices` interface and Julia's package-extension mechanism.

The scientific scope is experimental. The comparisons were qualified with
guidance and control at 3 Hz. The original physical limits are kept, and measured
exceedances are reported as violations. The implementation does not guarantee
that constraints are always met, and it does not reproduce the journal results
exactly. Read [Scientific status](docs/scientific_status.md) before interpreting
a run.

## Start here

1. Follow [Installation](docs/installation.md) to create an environment with a
   matching SpaceAGORA and companion pair. Julia 1.12 is required.
2. Read [How EDG works](docs/overview.md) for configuration, ownership, units
   and the meaning of the saved diagnostics.
3. Follow [Run and inspect the short example](docs/extension_guide.md#run-and-inspect-the-short-example)
   to launch the example and read its results, then see the
   [compatibility guide](docs/compatibility.md) before using EDG in a mission.
4. Use [Extending a study](docs/extension_guide.md) to change a case while keeping
   a comparison you can interpret.

The [validation record](docs/validation.md) lists the tested sources, the native
comparisons and the installation walkthroughs, with their limits.

Installing this package does not provide NASA GRAM model data. Studies with
native GRAM need separately obtained, authorized model data. SpaceAGORA's
standard atmosphere route uses a configured GRAMSuite installation; the retained
[native reference cases](benchmarks/native_reference/README.md) instead call
GRAM through a small lab-written bridge. They reproduce the depletion,
fixed-target and two-pass comparisons, need authorized native inputs and a pinned
research fixture, and are separate from the public extension interface. Label
synthetic or frozen-atmosphere examples as such; they do not qualify a native
atmosphere campaign.

## What is included

The package holds heat-rate and heat-load planning, the structural-load proxy,
candidate-specific targeting, the passage-heat calculations and the numerical
selection of a panel command. SpaceAGORA's adapter keeps the public types and
calls these algorithms with copied observations and scoped queries. There is one
active numerical implementation: SpaceAGORA 0.3.0 removed the older E-EDG and
T-EDG strategy routes from the core.

SpaceAGORA keeps the integrator, the physical heat integrals, the atmosphere and
frame services, the callback order and the panel actuation. The companion does
not advance or replace the simulator's physical state, and does not reset the
physical heat.

## Versions

| SpaceAGORAEDG | `EDGServices` contract | SpaceAGORA |
|---|---|---|
| 0.1.0 | 1.0.0 | its own pinned core revision |
| 0.2.0 | 2.0.0 | 0.2 and 0.3 |
| 0.3.0 | 2.0.0 | 0.3 and 0.4 |
| 0.4.0 | 2.0.0 | 0.4 and 0.5 |
| 0.5.0 | 3.0.0 | 0.6 |
| 0.5.1 (tag only) | 3.0.0 | 0.6 |
| 0.5.1, current `main` | 3.0.0 | 0.6 and 0.7 |

Contract 2.0.0 passes the run's EDG state to the decision services before the
configuration. Contract 3.0.0 removes two queries this package did not call.
Version 0.5.1 keeps the 0.5.0 code and adds the kernel regression tests that
SpaceAGORA 0.6.1 stopped running itself. Support for SpaceAGORA 0.7 is only on
`main`: the `v0.5.1` tag admits SpaceAGORA 0.6 only and has no GitHub release
page. SpaceAGORA v0.7.1 records commit `424d8aa8` of this repository, which
admits 0.7; [Installation](docs/installation.md) shows how to install that pair.

## Contributors

- [Giusy Falcone](https://github.com/gfalcon2)
- [Nihal Simha](https://github.com/NihalSimha)
- [Evan Yu](https://github.com/EvanY14)

These credits include development in SpaceAGORA before this package was extracted. See [Source and scientific attribution](NOTICE.md) for the earlier contribution history and scientific references.

## Publications and license

The original formulation is Falcone and Putnam's *Energy Depletion Guidance for
Aerobraking Atmospheric Passes* (2022). The generalized formulation is Simha, Yu
and Falcone's *Generalized Energy Depletion Guidance for Aerobraking at Mars,
Venus, Earth, and Titan* (2026). [References and current limitations](docs/scientific_status.md)
explains how they relate to the implementation.

This package is distributed under the [MIT license](LICENSE). See
[Source and scientific attribution](NOTICE.md) for its origin.
