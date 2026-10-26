# Validation of the experimental companion

This page records what was tested and the limits of that evidence. It is not a
certificate for a new spacecraft, atmosphere or targeting case; the
[scientific-status guide](scientific_status.md) explains the scope and the open
questions.

The source identities and counts below are records of the runs named in each
section, not a fresh check of every later commit. Use
[Installation](installation.md) for the current setup and
[Extending a study](extension_guide.md) for the checks to run locally. The native
reference recipe stays tied to its documented v0.1.0 source pair.

## Source identity

The native comparisons ran the frozen runtime source of core revision
`fbfe436264e651050435c8e65569496f49cb5dae` and companion revision
`a35549478fd7a38930d710a70419b537aa505121`. The frozen manifest covered 315 core
files and 10 companion files, with SHA-256
`59df0e84459abf746b31660eb1132a193ebc6dc1074c8a318151bea549cb0b87`. The
[runtime file hashes](../benchmarks/native_reference/validation/runtime_manifest.json)
identify the executed source, and the run records checked those files before and
after each comparison.

The core integration that followed included main revision
`fd6e10ac091e769710548a31816461a8b7ec0b9b`. Of the 325 runtime files, only the
validation of the named-atmosphere preset catalog changed, and the direct
native-GRAM recipe does not use that catalog. A source review confirmed that the
EDG, native-query, frame, integrator and thermal paths were unchanged, and 316
assertions passed for the changed preset behavior. That later integration is
therefore supported by the source review and its own focused checks; it is not
the revision that ran the long native campaign. Its standard installation, both
load orders, the public example and short preset and command-line checks passed
77 assertions.

`CoreSource.toml` identifies the core used by the standalone installer, and
SpaceAGORA's submodule identifies the companion used by SpaceAGORA's installer.

## Native comparisons

The three retained Mars cases use the original 3 Hz guidance and control, a
0.15 W/cm² heat-rate limit, a 30 J/cm² passage-heat limit and a 0.5 Pa structural
proxy limit. They keep the recorded initialization, native atmosphere settings,
solver and fixed early target. No target, rate or limit was adjusted to obtain
agreement. The [reference recipe](../benchmarks/native_reference/README.md) gives
the prerequisites and commands.

All three extracted trajectories match the integrated reference from before the
extraction, `0f486534022bc35c1e8f0f309d73e6db64be5d69`, byte for byte, and so do
their event and scientific metadata. The depletion case reaches the first
apoapsis after exit; the two-pass case reaches its second atmospheric exit and
does not complete the second coast. Endpoints come from the event and completion
records; the last saved CSV row need not fall exactly on the terminal event.

| Case | Saved rows | Peak sampled panel heat rate, W/cm² | Interpretation |
|---|---:|---:|---|
| Depletion | 19,447 | 0.15137451241766942 | Exceeds the original 0.15 limit. |
| Two passages | 38,624 | 0.15101616175344842 | Exceeds the original 0.15 limit. |
| Fixed early target | 19,439 | 0.004901645407919217 | Describes this matched case only. |

The peaks and violation counts describe saved samples and do not bound a peak
between samples. Agreeing with the reference keeps the known violations; it does
not make the trajectories feasible.

The fixed target was 19,780,944.9723878 m from the planet's centre. Planning
records occur at 3, 5 and 7 seconds, and the executed panel command switches at
8 seconds. The final apoapsis radius is 19,780,944.97007846 m, a signed radius
error of −0.0023093409836292267 m. This constructed early case exercises
replanning and switching; it says nothing about accuracy for arbitrary targets or
behavior near an active heat-budget limit.

The [machine-readable result summary](../benchmarks/native_reference/validation/results.json)
records the CSV hashes, row counts, sampled peaks, endpoints and preserved
settings. The recipe's provenance identifies the private comparison fixture,
driver and bridge inputs. These comparisons use a research fixture and are
separate from the public-interface walkthroughs below.

## Installation and extension walkthroughs

Two walkthroughs followed the published documentation on macOS arm64 with Julia
1.12.3. The first installed the pinned pair in a new project, repeated the setup,
exercised both load orders, ran the two-second example, interpreted its output
and changed the duration to three seconds. Repeating the two-second run gave
exactly the same controller diagnostics; the longer run changed the propagated
state while keeping the configuration and the 3 Hz cadence.

The second attached a zero-force, zero-torque component through the public force
interface. Coverage recorded 79 calls from the simulator, and the saved tables and
EDG summaries matched the unchanged example byte for byte. The component made no
direct calls into the propagation engine and changed no scientific settings. This
demonstrates the extension route, not the accuracy of an arbitrary new force
model.

Both walkthroughs were automated, not tests by an unaided human user, and they
used an existing dependency cache rather than a clean depot. The second reused
the first one's environment, so it was not a second installation. A harmless
plotting-startup warning appeared; plotting is disabled in the example.

## Automated checks

The kernel regression tests are this package's own. They came from SpaceAGORA's
EDG tests when SpaceAGORA stopped forwarding the kernels' helpers and kept only
its two decisions (SpaceAGORA 0.6.1). They reach each kernel through SpaceAGORA's
decision route, so SpaceAGORA projects the arguments and expires the prediction
handle as in a run (`test/kernel_fixtures.jl`). The package tests also cover the
service boundary, state isolation, handle expiry, the refusal without a provider,
both load orders and the installer's safeguards. SpaceAGORA keeps the tests of
what it owns: projection and handles, panel application, heat accounting,
callbacks, the run lifecycle and the command-line environment selection.

This repository's [workflow](../.github/workflows/ci.yml) installs the core
recorded in `CoreSource.toml` with the checkout under test and runs the package
tests and both load orders; [Installation](installation.md#continuous-integration)
lists its jobs. SpaceAGORA's CI installs the companion commit it records and
runs its own native, coverage and example checks with it. The current hosted
results are in the Actions runs of the two repositories. A running, missing or
failed required check is not a pass.

## NLsolve 5

`Project.toml` accepts NLsolve 4 and 5 (`NLsolve = "4, 5"`). This section records
the check made when NLsolve 5 was admitted. NonlinearSolve
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
| Widened | the same setup, with NLsolve 5 admitted | 4.5.1 | 4.28.0 | 7.10.0 | 7.5.1 |
| NLsolve moved | the widened environment with only these four packages moved | 5.0.1 | 4.32.0 | 8.0.1 | 7.8.2 |
| Fresh | core and this package resolved without a manifest | 5.0.1 | 4.32.0 | 8.0.1 | 7.8.2 |

The fresh environment also differs from the root manifest in 102 other
packages: 100 at other versions and 2 not installed. Each environment ran
core's suite 00 (the EDG suite, including its `:tpbvp_integration` control
tests), this package's tests and the Odyssey energy-depletion example
(heat-load phase, native Mars GRAM) with both heat-load solvers. At that time,
suite 00 passed 2,357 of 2,357 assertions and the package tests 41 of 41 in every
environment, with the same counts in each test set.

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
atmospheres, vehicles or targets. The core revisions pinned since contract 2.0.0
no longer depend on NLsolve, so the installer job's fresh resolution now picks
NLsolve 5, while the contributor job, which starts from the core's manifest, can
still use NLsolve 4.
