# GitHub workflow

Confirm remote, branch, and upstream before publishing. Do not assume the
remote is named `origin`. Do not mutate remote resources without authorization.

Before a PR, verify scope, tests, diff against base, and actionable release
risks. Never claim checks passed without verification.

A Git tag identifies a commit; a GitHub Release adds notes and assets. For Elo,
tags and releases are created through the GitHub Release interface after the
release PR reaches `main`. Verify the exact target commit.
