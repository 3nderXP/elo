# Git safety

Inspect working tree, index, HEAD, branch, upstream, and remote separately.
Use status, unstaged diff, staged diff, log, branch tracking, and remotes as
needed.

For every new LLM task, inspect the branch, working tree, upstream, and remotes
before editing. While on a clean `develop`, update from its configured remote
with `git pull --ff-only <remote> develop` and verify success before creating
the task branch. Do not assume the remote name. If the update cannot be a fast
forward, the upstream is missing, the working tree is dirty, or another branch
is checked out, ask the user what to do and do not stash, switch, pull, merge,
rebase, discard, or otherwise change history on their behalf.

Stage only task-owned files and review staged content before commit. Use
Conventional Commits and one commit per logical unit.

Prefer revert for shared changes. Rebase only with understood local effects.
Never assume force-push authorization; use `--force-with-lease` only when
explicitly authorized. Never delete refs or untracked files merely to clean up.
