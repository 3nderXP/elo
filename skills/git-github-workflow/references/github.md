# GitHub workflow

Confirm remote, branch, and upstream before publishing. Do not assume the
remote is named `origin`. Do not mutate remote resources without authorization.

Before a PR, verify scope, tests, diff against base, and actionable release
risks. Never claim checks passed without verification.

A Git tag identifies a commit; a GitHub Release adds notes and assets. For Elo,
tags and releases are created through the GitHub Release interface after the
release PR reaches `main`. Verify the exact target commit.

## After every push

After pushing a branch, ask the user whether to draft the PR description and
release notes as `.md` files at the repository root (untracked, for the user
to paste manually while opening the PR/release and to delete afterward — see
[Versioning and releases](releases.md) for the suffix/version rule):

- If this push is meant to ship as a release now: suggest the next version
  (and whether it needs an `-rc` suffix, per releases.md) and draft both the
  PR description and the release notes.
- If the user is instead accumulating commits on the remote branch toward a
  future `-rc` that later gets promoted to latest: draft only the PR
  description. Do not draft release notes or suggest a version yet — the user
  will ask for the release notes later, even with no new local commits to
  push, once they decide to cut the release.
