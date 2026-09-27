# GitFlow, versioning, and releases

## Branch model

```text
feature/* ─┐
fix/* ─────┴─ squash merge ─> develop
                                  └─ release PR ─> main ─> tag ─> Release
                                  └─ site-only PR ─> main   (no tag, no release)
```

- `main` contains releasable versions, exists authoritatively on GitHub, and
  accepts release PRs through normal merge commits.
- `main` may also carry site-only merges with no tag, as described under
  "What counts as a release".
- `develop` is the integration branch and accepts feature/fix PRs through
  squash merge.
- `feature/*` and `fix/*` branch from `origin/develop`.
- optional `release/vX.Y.Z` branches stabilize releases.
- `hotfix/*` branches from `origin/main`, targets `main`, receives a PATCH
  release, and must be reapplied to `develop`.

Temporary branches must not receive version tags.

## LLM task branches

Before modifying files or preparing a commit for a new task, every LLM MUST
inspect the current branch, working tree, upstream, and remotes. When it is
`develop`, the working tree must be clean and local `develop` must first be
updated from its configured upstream without merge commits:

```bash
git pull --ff-only <remote> develop
git switch -c <type>/<short-task-name> develop
```

`<remote>` is the remote tracked by local `develop`; do not assume its name.
Verify that the pull completed successfully before creating the task branch.
If the branch has diverged, has no valid upstream, contains local changes, or
cannot be updated, stop and request direction instead of stashing, rebasing,
merging, or discarding work automatically.

Use an appropriate prefix such as `feature/`, `fix/`, or `docs/`. If the
current branch is not `develop`, the LLM MUST ask the user what to do before
switching, pulling, rebasing, or editing. It must not silently reuse the current
branch or infer permission to return to `develop`. Release and hotfix work that
needs a different base therefore requires explicit user direction before the
LLM changes repository state.

## Versioning

Use `vMAJOR.MINOR.PATCH`. PATCH fixes compatibility, MINOR adds compatible
features, and MAJOR introduces incompatibility. Document breaking behavior
explicitly during `0.x`.

## What counts as a release

A release versions the CLI, and the CLI is defined by `specs/cli-contract.md`:
its commands, flags, output, exit codes and on-disk layout. The tag is the
release. A merge is not.

- A PR touching `elo.sh`, `lib/`, `install.sh`, `tests/`, or
  `specs/cli-contract.md` changes the contract and therefore requires a SemVer
  release with a tag, as usual.
- A PR touching only `site/`, `assets/branding/`, `scripts/inject-*.py`,
  `AGENTS.md`, or documentation and non-contract specs changes no part of the
  installed program. Merge it to `main` with **no release and no tag**. Bumping
  the version for it misleads every installer about what changed, because no
  user of the CLI receives a feature or a fix.
- The landing page is a separate published artifact with its own cadence. It
  deploys on every merge and versions itself from the CLI's latest release, not
  from its own commits.

Because site-only commits reach `main` without a tag, `main` legitimately runs
ahead of the highest tag. "What is released" is therefore the highest version
tag:

```bash
git tag --list 'v*' --sort=-v:refname | head -1
```

Never use `git describe` for this. It resolves the nearest tag reachable from
`HEAD`, not the highest version, so a branch that trails the newest tag reports
an older release — the version shown to users and the version recorded in
`site/index.html` must come from the tag list.

## Release flow

1. Confirm `develop` is releasable.
2. Choose the SemVer version.
3. Open `develop → main`.
4. Run all required checks.
5. Use a normal merge commit.
6. Open **Releases → Draft a new release**.
7. Use the version for both tag and title, e.g. `v0.1.0`.
8. Create the tag against the exact release commit on `main`.
9. Publish English release notes.

Do not create tags locally or tag commits before the release PR is merged.
Published tags are immutable; corrections require a new version.

## Release steps after tagging

The website names the CLI release it documents, so it is one release behind by
construction. After the tag exists, write that version into the page:

```bash
python3 scripts/inject-version.py
```

Commit the result as a site-only merge, with no new tag. Running the script
before tagging publishes a version that does not exist yet.

## GitHub protection

- `develop`: require PR, checks, conversation resolution, squash merge; block
  force push and deletion.
- `main`: require PR, checks, conversation resolution, merge commit; block
  direct push, force push, and deletion.
- `v*`: block updates and deletion while allowing authorized release creation.

Do not require linear history on `main` because release merge commits are
intentional.

## Release validation

```bash
bash -n install.sh elo.sh lib/*.sh tests/*.sh
./tests/test_elo.sh
./tests/test_provider.sh
./tests/test_mrpack.sh
./tests/test_install.sh
./tests/test_interactive.sh
```

Validate modified skills, review changes since the previous tag, verify English
documentation, and confirm the tag does not exist.

Before tagging, confirm the release is a CLI release: if the diff against the
previous tag is limited to `site/`, `assets/branding/`, `scripts/inject-*.py`,
`AGENTS.md` and documentation, close the release draft and delete the tag
instead of publishing a version the CLI did not earn.

## Reproducible installation

```bash
curl -fsSL \
  https://raw.githubusercontent.com/3nderXP/elo/v0.1.0/install.sh |
  bash -s -- --ref v0.1.0
```
