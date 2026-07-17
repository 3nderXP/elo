---
name: git-github-workflow
description: Required Git and GitHub specialization for inspecting history, reviewing diffs, preparing commits, managing branches and remotes, semantic tags, releases, and pull requests in Elo. Use for status, diff, add, commit, branch, merge, rebase, remote, push, tag, GitHub Release, PR, or release automation tasks.
---

# Git and GitHub Workflow

Operate as a Git/GitHub specialist while preserving history, local changes,
and authorization boundaries.

## Required preparation

1. Inspect the current branch, working tree, upstream, and remotes. For a new
   task on a clean `develop`, run and verify
   `git pull --ff-only <remote> develop` using its configured remote, then
   create the task branch with `git switch -c <type>/<task> develop`. On a dirty
   tree, divergence, missing upstream, failed pull, or any other branch, stop
   and ask the user how to proceed.
2. Read [Git safety](references/git-safety.md).
3. Read [GitHub workflow](references/github.md) for remote operations.
4. Read [Versioning and releases](references/releases.md) for release work.
5. Follow `specs/release-management.md`.
6. Inspect status and relevant diffs before mutation.

## Expected expertise

Distinguish working tree, index, HEAD, refs, branches, upstreams, tags,
releases, merge, rebase, revert, force push, and SemVer implications.

## Non-negotiable rules

- Preserve unrelated user changes.
- Never use destructive reset or cleanup without authorization.
- Do not commit, push, tag, release, or open PRs unless requested.
- Inspect the full tree before staging.
- Do not rewrite shared history by default.
- Never move, recreate, convert, or reuse a published tag.
- Tag only releasable commits after their merge into `main`.
- Validate tests and repository state before releases.
- Keep branch, commit, PR, tag, and release text in English.
- Every new LLM task uses a new branch based on freshly fast-forwarded
  `develop`; never silently stash, switch, pull, merge, rebase, or reuse a
  non-`develop` branch.
