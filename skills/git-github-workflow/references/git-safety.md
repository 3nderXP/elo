# Git safety

Inspect working tree, index, HEAD, branch, upstream, and remote separately.
Use status, unstaged diff, staged diff, log, branch tracking, and remotes as
needed.

For every new LLM task, inspect the branch before editing. Create the task
branch from local `develop` only while currently on `develop`. If another
branch is checked out, ask the user what to do and make no branch-changing or
history-changing decision on their behalf.

Stage only task-owned files and review staged content before commit. Use
Conventional Commits and one commit per logical unit.

Prefer revert for shared changes. Rebase only with understood local effects.
Never assume force-push authorization; use `--force-with-lease` only when
explicitly authorized. Never delete refs or untracked files merely to clean up.
