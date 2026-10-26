# Scientific status

SpaceAGORAEDG is experimental, with a deliberately narrow scope: it is a
reproducible package and adapter that keeps its known limitations. It does not
certify every trajectory, and it does not reproduce the published figures
exactly.

## Accepted scope

The supported scientific route is the closed-form energy-depletion policy and
candidate-specific targeting, under the documented examples and matching
conditions. The numerical shooting route remains experimental, kept for
compatibility and reference. A converged solve does not by itself show that a new
case is scientifically valid.

Guidance and control run at 3 Hz in the comparisons, with the original limits.
Because a command is held between updates, the propagated heat rate can exceed
its threshold in between; those exceedances are violations. No extra margin,
clipping law or faster update has been added to hide them.

When even the minimum panel angle exceeds the modeled structural bound, the
original minimum-drag policy stays in place and the case must be reported as
infeasible. This is a different situation from thermal excursions caused by
sampled control. Applying a fallback command makes neither of them feasible.

Targeting builds a sampled family of candidates on the grid of commands that can
actually be executed. Each candidate has its own atmospheric passage, remaining
heat budget and coast to apoapsis. An ordered admissible prefix of that grid does
not prove optimality over the continuous family, and optimality with the full
Cartesian state, moving events and active bounds is not proved.

## What the retained native comparisons show

The retained comparison has three cases: a fixed early target, a depletion
passage and two passages. The early target exercises replanning and a later
switch; it says nothing about accuracy for arbitrary targets or behavior near the
heat-budget limit. The two-pass case ends at the second atmospheric exit and
does not include the whole second coast.

For the integrated code before extraction (SpaceAGORA commit
`0f486534022bc35c1e8f0f309d73e6db64be5d69`), repeated depletion and two-pass runs
matched the retained trajectories, event records and passage-heat records byte
for byte. Their peak sampled panel heat rates, about 0.1514 and 0.1510 W/cm²,
exceed the original 0.15 W/cm² limit and remain violations; the
[validation record](validation.md) has the exact values. Counts and maxima taken
from saved samples do not bound a peak between samples.

Those trajectories are the reference from before the extraction. The validation
record describes the later companion reruns, how the sources were composed and
the installation checks. Older trajectories alone do not qualify a later package
revision: keep the exact source pair with the evidence for a new study.

## What remains open

The original calibration inputs, fit settings and the identity of the runs
plotted in the journal papers have not all been recovered. Matching the printed
coefficients after a change of polynomial basis does not recover the original
calibration or trajectory. The Mars epoch is uncertain; the Earth normalization is
either 275 or 275.5 km; and the Titan interface and fitted-domain assumptions
differ. Do not resolve these by choosing whichever initialization gives a nicer
plot.

The package makes no claim of exact reproduction of the journal results,
real-time throughput, accuracy at every planet, constraint satisfaction in every
case or optimality for arbitrary targets. New atmospheres, spacecraft, wind
settings, active bounds and mission histories need their own documented
validation.

## References

1. Giusy Falcone and Zachary R. Putnam, “Energy Depletion Guidance for Aerobraking
   Atmospheric Passes,” *Journal of Guidance, Control, and Dynamics*, 45(4),
   2022, pp. 651–668. [DOI: 10.2514/1.G006171](https://doi.org/10.2514/1.G006171).
2. Nihal Simha, Evan Yu and Giusy Falcone, “Generalized Energy Depletion Guidance
   for Aerobraking at Mars, Venus, Earth, and Titan,” *AIAA SciTech 2026 Forum*,
   2026. [DOI: 10.2514/6.2026-1378](https://doi.org/10.2514/6.2026-1378).

Cite these publications for the method. Cite the software revision you used, and
its evidence, separately.
