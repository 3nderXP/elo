# GitFlow, versioning, and releases

## Branch model

```text
feature/* ─┐
fix/* ─────┴─ squash merge ─> develop
                                  └─ release PR ─> main ─> tag ─> Release
```

- `main` contains releasable versions, exists authoritatively on GitHub, and
  accepts release PRs through normal merge commits.
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

## Reproducible installation

```bash
curl -fsSL \
  https://raw.githubusercontent.com/3nderXP/elo/v0.1.0/install.sh |
  bash -s -- --ref v0.1.0
```
