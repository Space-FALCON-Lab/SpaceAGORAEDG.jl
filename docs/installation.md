# Installing the EDG companion

SpaceAGORAEDG supplies experimental energy-depletion guidance for SpaceAGORA.
Use Julia 1.12 and the exact core and companion pair recorded for the release.
The package version constraint, the SpaceAGORA 0.6 and 0.7 families, is only the first
compatibility check: this implementation also requires EDGServices contract 3.0.0.
Version 0.1.0 of this package implements contract 1.0.0 with its own pinned core.

## From a SpaceAGORA checkout

A qualified SpaceAGORA revision records the companion commit as a Git submodule
under `packages/gnc/SpaceAGORAEDG.jl`. From that checkout, run:

```sh
julia --startup-file=no scripts/optional_packages.jl setup edg /path/to/edg-env
julia --startup-file=no --project=/path/to/edg-env
```

Then load the packages explicitly:

```julia
using SpaceAGORA, SpaceAGORAEDG
SpaceAGORA.EDGServices.require_provider()
```

The helper verifies the companion's origin, revision, identity and clean state.
It initializes only that repository and creates a separate environment. It
refuses a changed checkout rather than resetting someone's work. Keep both
source checkouts in place while using this environment.

## From the companion repository

Clone this repository at the release's recorded commit. Its `CoreSource.toml`
must contain the full immutable core revision qualified with that companion:

```sh
git clone https://github.com/Space-FALCON-Lab/SpaceAGORAEDG.jl.git
cd SpaceAGORAEDG.jl
julia --startup-file=no scripts/setup_env.jl /path/to/edg-env
julia --startup-file=no --project=/path/to/edg-env
```

The installer fetches only that core revision, without recursively initializing
its submodules. It records ownership of the managed checkout, installs core and
the companion explicitly, and keeps the environment outside both source trees.
It reuses its own unchanged setup and refuses an existing unmanaged environment.
A Julia project may download ordinary package dependencies during setup.

The immutable core revision is published in `CoreSource.toml`. The
[validation record](validation.md) distinguishes native comparisons, integration
review and installation walkthroughs. The versioned release identifies the
final qualified pair after hosted checks and merge approval. A package version
range alone is not evidence that an arbitrary core revision is compatible.

## Working on both packages

For local development, select the core checkout explicitly:

```sh
SPACEAGORA_CORE_PATH=/absolute/path/to/SpaceAGORA.jl \
  julia --startup-file=no scripts/setup_env.jl /path/to/edg-development-env
```

The installer checks its package identity and leaves that checkout unchanged.
Alternatively, `SPACEAGORA_CORE_REV` may select a full published 40-character
core commit. Set only one override. A path selects working source; it is not
evidence that those edits have passed scientific validation.

The core's `scripts/setup_edg.jl` is a test helper. It accepts
`SPACEAGORA_EDG_PATH` for an explicit companion checkout and keeps the core's
dependency versions in a separate test environment. Release instructions use
the pinned installer above, rather than an unrecorded local path.

## Validation and release order

Core owns physical state, mission lifecycle and application of the resulting
commands. The companion owns the extracted numerical planner. Loading either
package first must activate the same extension. Loading core alone must succeed,
and an EDG operation without the companion must give a clear error.

Installation checks do not replace the native campaign. The bounded experimental
release retains the approved original rates and limits; known violations are
reported, not relabeled as acceptable. No model setting is changed by installation.

Maintainers complete publication in this order:

1. Review and publish the qualified core facade commit to an integration branch.
2. Record that actual immutable revision in this companion's `CoreSource.toml`;
   validate standalone installation, both load orders and companion tests.
3. Publish the reviewed companion commit, then record it as the core's EDG
   gitlink. Revalidate the final source pair, including the existing EDG,
   native, coverage and example suites and required repository checks.
4. Merge and release only after the final pair passes. Preserve the exact source,
   asset and validation records used to make that decision.

The `core-release-pin` check passes only when the core commit in
`CoreSource.toml` is a SpaceAGORA release. While step 2 pins a facade commit that
is not yet released, that check fails: the companion is not ready for release
until its pin moves to the core release.

No guessed, floating or unpublished revision serves as a release pin.

## Continuous integration

The pinned SpaceAGORA contributor workflow runs strict precompilation, the full
EDG test suite with deprecations treated as errors, incompatible-core refusal,
and both package load orders in an isolated environment. It also checks that
tracked inputs remain unchanged and publishes conformance reports. The full
suite runs directly from `test/runtests.jl` with the core-seeded dependencies;
the shared workflow does not force `Pkg.test`'s bounds-checking mode.

EDG keeps its own installer preflight, a standalone installation smoke test and
the released-core pin check. These exercise the public installation route in
addition to the shared workflow's environment builder.

`SpaceAGORASource.toml` records the shared workflow's core; `CoreSource.toml`
records the standalone installer's core. Their URL, UUID and revision must agree,
and CI checks this. When updating the pair, update both files and the workflow's
`uses` SHA and `spaceagora-rev` together. The current checkout pins the published
SpaceAGORA v0.7.0 commit for both routes, retaining EDGServices contract 3.0.0.

The shared workflow calls `test/load_order.jl companion-first`; `edg-first`
remains an alias for local use.
