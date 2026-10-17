# Validation of the experimental companion

This record identifies what was tested and the limits of that evidence. It is
not a certificate for a new spacecraft, atmosphere or targeting case. The
[scientific-status guide](scientific_status.md) explains the accepted scope and
the questions that remain open. A release also requires the final published
pair to pass hosted checks and receive merge approval.

## Source identity

The native comparisons executed the frozen runtime source published in core
revision `fbfe436264e651050435c8e65569496f49cb5dae` and companion revision
`a35549478fd7a38930d710a70419b537aa505121`. The frozen manifest
covered 315 core files and 10 companion files; its SHA256 was
`59df0e84459abf746b31660eb1132a193ebc6dc1074c8a318151bea549cb0b87`.
The [runtime file hashes](../benchmarks/native_reference/validation/runtime_manifest.json)
identify the executed source. Execution receipts check those files before and
after each comparison.

The subsequent core integration incorporates main revision
`fd6e10ac091e769710548a31816461a8b7ec0b9b`. Of those 325 runtime files, only
named-atmosphere preset catalog validation changed. The direct native-GRAM
recipe does not call that catalog path. Independent source review confirmed
that its EDG, native-query, frame, integrator and thermal paths are unchanged;
316 assertions passed for the changed preset behavior. The later integration
is therefore supported by source-composition review and its own focused checks,
not described as the revision that executed the long native campaign. Its
standard parent installation, both load orders, public example and bounded
preset/CLI diagnostics passed 77 assertions.

`CoreSource.toml` identifies the immutable core used by the standalone installer.
The SpaceAGORA gitlink identifies the companion used by the parent installer.
The release records both final identities and the verified merge commits.

## Native comparisons

The three retained Mars cases use the original 3 Hz guidance and control,
0.15 W/cm² heat-rate limit, 30 J/cm² passage-heat limit and 0.5 Pa structural
proxy limit. They retain the recorded initialization, native atmosphere settings,
solver and fixed early target. No target, rate or limit was adjusted to obtain
agreement. See the [reference recipe](../benchmarks/native_reference/README.md)
for prerequisites and commands.

All three extracted trajectories match the integrated
pre-extraction reference `0f486534022bc35c1e8f0f309d73e6db64be5d69` byte for byte.
Their event and scientific metadata also agree. Depletion reaches the first
post-exit apoapsis; the two-pass case reaches its second atmospheric exit and
does not complete the second coast. Endpoints come from the event and completion
records; the last sampled CSV row need not fall exactly on the terminal event.

| Case | Saved rows | Peak sampled panel heat rate, W/cm² | Interpretation |
|---|---:|---:|---|
| Depletion | 19,447 | 0.15137451241766942 | Exceeds the original 0.15 limit. |
| Two passages | 38,624 | 0.15101616175344842 | Exceeds the original 0.15 limit. |
| Fixed early target | 19,439 | 0.004901645407919217 | Describes this matched case only. |

The peaks and violation counts describe saved samples. They do not bound an
unobserved continuous-time peak. Agreement with the reference preserves the
known violations; it does not make the trajectories feasible.

The fixed target was 19,780,944.9723878 metres from the planet centre. Planning
records occur at 3, 5 and 7 seconds, and the executed panel command switches at
8 seconds. The final apoapsis radius is 19,780,944.97007846 metres: a signed
radius error of −0.0023093409836292267 metres. This constructed early case
exercises replanning and switching; it does not establish arbitrary-target
accuracy or behavior near an active heat-budget boundary.

The [machine-readable result summary](../benchmarks/native_reference/validation/results.json)
records CSV hashes, row counts, sampled peaks, endpoints and preserved settings.
The linked recipe provenance identifies the private comparison fixture, driver
and bridge inputs. These research-fixture comparisons are separate from the
public-interface installation and extension walkthroughs below.

## Installation and extension walkthroughs

Independent agents followed the published candidate documentation on macOS
arm64 with Julia 1.12.3. The newcomer installed the pinned pair in a new project,
repeated setup, exercised both package load orders, ran the two-second example,
interpreted its output and changed the documented duration to three seconds.
The repeated two-second controller diagnostics agreed exactly. The longer run
changed the propagated state while retaining the configuration and 3 Hz cadence.

A separate agent attached a pure zero-force/zero-torque component through the
documented public force interface. Coverage recorded 79 calls from the simulator;
the saved tables and EDG summaries matched the unchanged example byte for byte.
The component made no direct calls into the propagation engine and changed no
scientific settings. This demonstrates the bounded extension route, not the
accuracy of an arbitrary new force model.

The trials used an existing dependency cache. The extension trial reused the
newcomer's installed environment; it is not a second installation trial. They
are agent walkthroughs, not unaided human acceptance or clean-depot evidence.
A nonfatal plotting-startup warning was retained; plotting was disabled in the
example. The extension author could not inspect an older linked revision from
the shallow local checkout. Independent verification found that the public page
existed and was unchanged. Links now follow the supported core revision, and
the output guide explains the saved endpoint and thermal-summary distinctions.

## Automated checks and remaining gates

The extraction retains the existing core EDG numerical tests and includes the
companion's numerical sources in the original coverage gate. Local checks cover
the service boundary, state isolation, lease expiry, missing-provider refusal,
both load orders, CLI environment selection and installation safeguards. The
core PR contract suite passed all 31 gates and 49 negative controls before the
final preset-catalog integration; the changed preset tests then passed separately.

The [companion workflow](../.github/workflows/ci.yml) tests installation of its
public immutable pair, its package tests and both load orders. SpaceAGORA adds
mandatory EDG installation to its native, coverage, examples and other required
checks. Consult [core PR289](https://github.com/Space-FALCON-Lab/SpaceAGORA.jl/pull/289)
and [companion PR1](https://github.com/Space-FALCON-Lab/SpaceAGORAEDG.jl/pull/1)
for the final hosted results. A running, absent or failed required check is not
a release pass.

The first hosted example run exposed a launcher defect: its isolated child
project omitted the EDG provider. The launcher now selects the validated paired
project for the two EDG examples, retaining the original smoke settings and
isolated load path. A focused subprocess regression passed 16 assertions and
reproduced the original missing-package error when run against the old launcher.
The repaired source pair still requires fresh hosted checks.

## NLsolve 5

`Project.toml` accepts NLsolve 4 and 5 (`NLsolve = "4, 5"`). NonlinearSolve
4.28.1 and later accept only NLsolve 5, so with NLsolve 4 alone an environment
holding this package had to keep NonlinearSolve at 4.28.0 or older.

The package calls NLsolve in one place: the heat-load TPBVP shooting in
`src/heat_load.jl`, used only with `heat_load_switch_solver = :tpbvp_integration`.
That call uses the trust-region method with its own Jacobian and passes no
`autodiff` argument, so the NLsolve 5 interface change does not reach it. From
NLsolve 4.5.1 to 5.0.1 the trust-region solver changes only its column-scaling
guard, which now also resets a scale whose square underflows. A shooting
solution is accepted only when the scaled infinity norm of its terminal-costate
residual is at most `1e-3` (`_EDG_HEAT_LOAD_SHOOTING_RESIDUAL_TOL`); otherwise
the run stops with an error. That tolerance applies to the residual, not to the
trajectory, so the comparison below records differences rather than testing
them against a threshold.

The checks ran on macOS arm64 with Julia 1.12.7 and SpaceAGORA main
`ed834687f`, in four environments:

| Environment | Built from | NLsolve | NonlinearSolve | NLSolversBase | LineSearches |
|---|---|---|---|---|---|
| Before | core's EDG setup (root manifest), this package's `main` | 4.5.1 | 4.28.0 | 7.10.0 | 7.5.1 |
| Widened | the same setup with this change | 4.5.1 | 4.28.0 | 7.10.0 | 7.5.1 |
| NLsolve moved | the widened environment with only these four packages moved | 5.0.1 | 4.32.0 | 8.0.1 | 7.8.2 |
| Fresh | core and this package resolved without a manifest | 5.0.1 | 4.32.0 | 8.0.1 | 7.8.2 |

The fresh environment also differs from the root manifest in 102 other
packages: 100 at other versions and 2 not installed. Each environment ran
core's suite 00 (the EDG suite, including its `:tpbvp_integration` control
tests), this package's tests and the Odyssey energy-depletion example
(heat-load phase, native Mars GRAM) with both heat-load solvers. Suite 00 passed
2,357 of 2,357 assertions and the package tests 41 of 41 in every environment,
with the same per-testset counts.

- Widened: the manifest equals the one before apart from this package's path.
  Both example runs write byte-identical `simulation_results.csv` files.
- NLsolve moved: both example runs, closed form and TPBVP, again write
  byte-identical files. The TPBVP run solves the same heat-load switches and
  follows the same trajectory as with NLsolve 4.5.1.
- Fresh: both example runs complete, so every shooting solve met the `1e-3`
  acceptance, and the solved switches are identical. Both trajectories differ
  from the ones before, including the closed-form run, which never calls
  NLsolve. The first difference appears at round-off level just after
  atmospheric entry and grows through the heat-load security switching, where
  the panel command changes at different samples. Because the NLsolve-moved
  environment reproduces the earlier files byte for byte, these differences
  come from the other package updates, not from NLsolve.

These are runs of one case on one machine. They show that NLsolve 5 reproduces
this case's shooting solution; they do not establish behavior for other
atmospheres, vehicles or targets. The companion workflow still installs the core
revision in `CoreSource.toml`, which itself requires NLsolve 4, so the hosted
checks keep using NLsolve 4 until that pin moves to a core revision that no
longer depends on NLsolve.
