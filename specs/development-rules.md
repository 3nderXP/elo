# Development rules

- Before changing files, an LLM MUST inspect the current Git branch, working
  tree, upstream, and remotes. If the branch is `develop`, it MUST first require
  a clean working tree and update `develop` from its configured upstream with an
  explicit fast-forward-only pull. It MUST verify the pull succeeded, then
  create and switch to a new task branch with
  `git switch -c <type>/<task> develop`. A divergence, missing upstream, failed
  pull, or dirty tree MUST stop this automatic flow instead of being resolved
  implicitly. If the initial branch is not `develop`, the LLM MUST stop and ask
  the user how to proceed; it MUST NOT switch branches, pull, rebase, or choose a
  different base without that decision.
- User-data preservation takes priority.
- Default behavior must be reversible.
- Each responsibility has one owning module.
- Configuration and state are data, never executable code.
- Runtime dependencies require an explicit architecture decision.
- Business logic must not be added to `elo.sh`.
- Python, Node.js, Go, and Rust are outside the Bash MVP.
- Tests must never access real user data.
- All tracked text must be English.

Before completion, run syntax checks, integration and interactive delegation
tests, skill validation when applicable, and diff checks. Update specs for
changed contracts and record new limitations.
