# Scientific status

SpaceAGORAEDG has a bounded experimental scope. This scope
allows a reproducible package and adapter to be delivered while retaining
known limitations. It does not certify every trajectory or establish exact
reproduction of the published figures.

## Accepted scope

The supported scientific route is the reviewed closed-form energy-depletion
policy and candidate-specific targeting under the documented examples and
matched conditions. The numerical shooting route remains experimental
compatibility and reference work. A converged solve is not by itself evidence
that a new case is scientifically valid.

Guidance and control run at **3 Hz** in the qualified comparisons. The original
limits remain unchanged. A held command can allow the propagated heat rate to
exceed its threshold between updates; those exceedances are violations. No
extra margin, clipping law or faster update has been introduced to conceal them.

When even the minimum panel angle exceeds the modeled structural bound, the
original minimum-drag policy remains in place and infeasibility must be
reported. This situation is distinct from thermal excursions caused by sampled
control. Neither situation is converted into a feasible result by applying a
fallback command.

Targeting builds a sampled family on the actual executable command grid. Each
candidate uses its own atmosphere passage, remaining heat budget and coast to
apoapsis. An ordered admissible prefix of that grid is not a continuous-family
optimality proof. Full Cartesian, moving-event and active-bound adjoint
optimality remains unproved.

## What the retained native comparisons show

The current-main integration comparison includes a fixed early targeting case,
a depletion passage and two passages. The early target exercises replanning
and a subsequent switch; it does not establish arbitrary-target accuracy or
behavior near the heat-budget boundary. The two-pass case ends at the second
atmospheric exit and does not include the entire second coast.

For the pre-extraction integrated candidate `0f486534022bc35c1e8f0f309d73e6db64be5d69`,
the repeated depletion and two-pass trajectories, event records and passage-heat
records matched the retained comparison outputs byte for byte. Their measured
peak panel heat rates were respectively 0.15137451241766942 and
0.15101616175344842 W/cm² against the original 0.15 W/cm² limit. These remain
violations. Counts and maxima taken from saved samples do not bound an
unobserved continuous-time peak.

Those trajectories identify the pre-extraction reference. The
[validation record](validation.md) describes the subsequent companion reruns,
source composition and installation checks. Historical trajectories alone do
not qualify a later package revision; keep the exact source pair with the
evidence for a new study.

## What remains open

The original calibration inputs, fit settings and plotted journal run identity
have not all been recovered. Matching printed coefficients after a polynomial
basis conversion does not establish the original calibration or trajectory.
Mars epoch placement remains uncertain; Earth normalization differs between
275 and 275.5 km; Titan interface and fitted-domain assumptions differ. These
uncertainties must not be resolved by choosing whichever initialization gives
a more attractive plot.

The release makes no claim of exact journal reproduction, real-time throughput,
all-planet accuracy, universal constraint satisfaction or arbitrary-target
optimality. New atmospheres, spacecraft, wind settings, active bounds and
mission histories require their own documented validation.

## References

1. Giusy Falcone and Zachary R. Putnam, “Energy Depletion Guidance for Aerobraking
   Atmospheric Passes,” *Journal of Guidance, Control, and Dynamics*, 45(4),
   2022, pp. 651–668. [DOI: 10.2514/1.G006171](https://doi.org/10.2514/1.G006171).
2. Nihal Simha, Evan Yu and Giusy Falcone, “Generalized Energy Depletion Guidance
   for Aerobraking at Mars, Venus, Earth, and Titan,” *AIAA SciTech 2026 Forum*,
   2026. [DOI: 10.2514/6.2026-1378](https://doi.org/10.2514/6.2026-1378).

These publications supply scientific context and attribution. The implementation
and the evidence for a particular software revision should be cited separately.
