# Development rules

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
