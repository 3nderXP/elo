# Development rules

- Before changing files, an LLM MUST inspect the current Git branch. If it is
  `develop`, the LLM MUST create and switch to a new task branch based on local
  `develop` with `git switch -c <type>/<task> develop`. If the current branch is
  not `develop`, the LLM MUST stop and ask the user how to proceed; it MUST NOT
  switch branches, rebase, or choose a different base without that decision.
- User-data preservation takes priority.
- Default behavior must be reversible.
- Each responsibility has one owning module.
- Configuration and state are data, never executable code.
- Runtime dependencies require an explicit architecture decision.
- Business logic must not be added to `elo.sh`.
- Python, Node.js, Go, and Rust are outside the Bash MVP.
- Tests must never access real user data.
- All tracked text must be English.

Before completion, run syntax checks, integration tests, skill validation when
applicable, and diff checks. Update specs for changed contracts and record new
limitations.
