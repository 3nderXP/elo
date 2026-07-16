---
name: elo-development
description: Required knowledge for developing, reviewing, testing, or documenting Elo with Bash, symlinks, and Minecraft data. Use for changes to elo.sh, lib/*.sh, tests/*.sh, .conf files, backup/reset flows, repository structure, or Elo technical specifications.
---

# Elo Development

Develop Elo as a modular Bash CLI that prioritizes user-data preservation.

## Required preparation

1. Inspect the current Git branch, working tree, upstream, and remotes before
   changing files. If it is a clean `develop`, update it from its configured
   upstream with `git pull --ff-only <remote> develop`, verify success, then
   create a new task branch with `git switch -c <type>/<task> develop`. Do not
   assume the remote name. On a dirty tree, divergence, missing upstream, pull
   failure, or any branch other than `develop`, stop and ask the user how to
   proceed.
2. Read `specs/README.md`.
3. Read every reference in this skill:
   - [Bash and shell](references/bash.md)
   - [Minecraft domain](references/minecraft.md)
   - [Filesystem safety](references/filesystem-safety.md)
   - [Testing](references/testing.md)
4. Read the area-specific specs.
5. Inspect existing code before introducing abstractions.

## Workflow

1. Identify the module that owns the responsibility.
2. Confirm backup, state, and symlink-ownership invariants.
3. Make the smallest architecture-consistent change.
4. Add or update isolated tests.
5. Run `bash -n install.sh elo.sh lib/*.sh tests/*.sh`.
6. Run all integration test scripts and the interactive delegation test.
7. Update affected specs when contracts change.

## Non-negotiable rules

- Never remove unknown data without confirmation.
- Never trust `-L` alone; validate link targets against state.
- Never overwrite original backups.
- Never execute `.conf` files with `source` or `eval`.
- Validate user-controlled path components.
- Keep CLI parsing separate from filesystem logic.
- Never access real user data in tests.
- Keep all tracked project text in English.
- Never begin a task on stale `develop`; fast-forward it and create the task
  branch first. Never stash, switch, pull, rebase, merge, or discard work to
  resolve a blocked preparation flow without the user's decision.
