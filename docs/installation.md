# Installing the EDG companion

SpaceAGORAEDG supplies experimental energy-depletion guidance for SpaceAGORA. Use
Julia 1.12 and a SpaceAGORA and companion pair that were tested together. The
package's version range for SpaceAGORA (0.6 and 0.7 on `main`) is only the first
check; the companion also requires `EDGServices` contract 3.0.0. Version 0.1.0 of
this package implements contract 1.0.0 with its own pinned core.

## From a SpaceAGORA checkout

This is the route for a SpaceAGORA release. Each SpaceAGORA revision records a
companion commit as a Git submodule under `packages/gnc/SpaceAGORAEDG.jl`;
SpaceAGORA v0.7.1 records commit `424d8aa8`. From a Git clone of SpaceAGORA at
that release, run:

```sh
julia --startup-file=no scripts/optional_packages.jl setup edg /path/to/edg-env
julia --startup-file=no --project=/path/to/edg-env
```

Then load the packages explicitly:

```julia
using SpaceAGORA, SpaceAGORAEDG
SpaceAGORA.EDGServices.require_provider()
```

The setup command checks the companion's origin, revision, package identity and
clean state, initializes only that submodule, and installs the companion with the
SpaceAGORA checkout you ran it from into a separate environment. It refuses a
modified checkout rather than resetting someone's work. Keep both source
checkouts in place while you use the environment. Use a Git clone: a GitHub
source archive does not contain submodules.

## From the companion repository

The companion's own installer reads the core revision from `CoreSource.toml`. On
`main` that is SpaceAGORA v0.7.0 (`bec28fcc`):

```sh
git clone https://github.com/Space-FALCON-Lab/SpaceAGORAEDG.jl.git
cd SpaceAGORAEDG.jl
julia --startup-file=no scripts/setup_env.jl /path/to/edg-env
julia --startup-file=no --project=/path/to/edg-env
```

To install SpaceAGORA v0.7.1 with this checkout instead, name its commit for the
installer:

```sh
SPACEAGORA_CORE_REV=db33b871795c9777037e6b6538996b08faec9aff \
  julia --startup-file=no scripts/setup_env.jl /path/to/edg-env
```

The installer fetches only that core revision, without initializing its
submodules, records that it manages the checkout, installs the core and the
companion, and keeps the environment outside both source trees. Running it again
reuses its own unchanged setup, and it refuses an existing environment it did not
create. Ordinary package dependencies may be downloaded during setup.

The release tags do not admit SpaceAGORA 0.7: `v0.5.0` and `v0.5.1` require
SpaceAGORA 0.6, and the installer in either tag installs SpaceAGORA v0.6.0, the
release its `CoreSource.toml` names. The [validation record](validation.md) separates the
native comparisons, the integration checks and the installation walkthroughs. A
version range alone does not show that an arbitrary core revision works.

## Working on both packages

For local development, point the installer at your own core checkout:

```sh
SPACEAGORA_CORE_PATH=/absolute/path/to/SpaceAGORA.jl \
  julia --startup-file=no scripts/setup_env.jl /path/to/edg-development-env
```

The installer checks the checkout's package identity and leaves it unchanged.
Alternatively, `SPACEAGORA_CORE_REV` selects a full 40-character core commit, as
above. Set only one of the two. A local path selects working source; it does not
show that those edits have passed scientific validation.

SpaceAGORA's `scripts/setup_edg.jl` prepares a core test environment with the EDG
provider. It accepts `SPACEAGORA_EDG_PATH` for an explicit companion checkout,
which at SpaceAGORA v0.7.1 must be version 0.5.1, and keeps the core's dependency
versions in a separate test environment. For results you intend to report, use
one of the pinned routes above rather than an unrecorded local path.

## Loading and ownership

The core owns the physical state, the mission lifecycle and the application of
the resulting commands; the companion owns the extracted numerical planner.
Either package can be loaded first and the same extension is activated. Loading
the core alone works, and an EDG operation without the companion fails with a
clear error.

Installation checks do not replace the native campaign. The experimental release
keeps the original rates and limits, and known violations are reported as
violations. Installation changes no model setting.

## Changing the core pin

Two files record the core revision. `CoreSource.toml` is read by the standalone
installer; `SpaceAGORASource.toml` by SpaceAGORA's shared contributor workflow.
Their URL, UUID and revision must agree, and the installer job checks this. To
move to another SpaceAGORA release, update both files together with the
workflow's `uses` commit and `spaceagora-rev`, the `version` in
`SpaceAGORASource.toml`, the `version_family` in `CoreSource.toml`, and the
SpaceAGORA links pinned to the old commit in [Extending a study](extension_guide.md).
Pin only published commits.

The `core-release-pin` job checks that the commit in `CoreSource.toml` is a
SpaceAGORA release tag, that `version_family` matches that release, and that the
package's `[compat]` admits it. While the pin is an unreleased core commit, this
job fails; the companion is not ready for release until the pin moves to a
SpaceAGORA release.

## Continuous integration

The workflow in `.github/workflows/ci.yml` has three jobs, all against the core
in `CoreSource.toml` (SpaceAGORA v0.7.0 on `main`):

| Job | Required | What it runs |
|---|---|---|
| `installation-and-contract` | yes | The installer's safeguard tests, a fresh installation with `scripts/setup_env.jl`, the full test suite through `Pkg.test` with bounds checking, the incompatible-core refusal, both load orders (`test/load_order.jl core-first` and `edg-first`), and a check that the checkout is unchanged. |
| `contributor-contract` | no | SpaceAGORA's shared contributor workflow, with the core revision from `SpaceAGORASource.toml`: strict precompilation, the suite run directly from `test/runtests.jl` with deprecations as errors (without `Pkg.test`'s bounds-checking mode), the incompatible-core refusal and both load orders, in an environment seeded from the core's manifest; it also checks that tracked files are unchanged and publishes conformance reports. |
| `core-release-pin` | no | `test/core_release_pin.jl`, described above. |

The two environments resolve dependencies differently: the installer job resolves
afresh, while the contributor job starts from the core's manifest.
`test/load_order.jl` accepts `companion-first` as another name for `edg-first`.

SpaceAGORA's own CI separately installs the companion commit its checkout records
and runs this package's tests and load orders with it.

### Updating shared support

`SharedSupport.toml` pins the SpaceAGORA revision that this repository's
generated support files come from; each file's header names its source file and
SHA-256. To change one, edit the source in SpaceAGORA, run
`scripts/sync_companion_support.jl --write` there against this checkout, then
update the pin. The Shared companion support workflow
(`.github/workflows/shared-support.yml`) compares the copies with the pinned
source. This pin is independent of the core revision used for the numerical tests.
