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
./tests/test_install.sh
```

Validate modified skills, review changes since the previous tag, verify English
documentation, and confirm the tag does not exist.

## Reproducible installation

```bash
curl -fsSL \
  https://raw.githubusercontent.com/3nderXP/elo/v0.1.0/install.sh |
  bash -s -- --ref v0.1.0
```
