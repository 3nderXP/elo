# Bash and shell

- Write Bash `.sh` scripts compatible with Bash 3.2 where practical.
- Avoid associative arrays, `local -n`, `mapfile`, and newer-only expansion.
- Use `#!/usr/bin/env bash` and strict mode in executables and tests.
- Quote expansions and validate path components.
- Use `[ -L "$path" ]` for broken-link-safe detection.
- Never use `eval` or execute configuration with `source`.
- Prefer `printf` for predictable output.
- Prefix functions with `elo_`; reserve `elo_cmd_` for CLI handlers.
- Keep destructive operations in their owning module.
- Use `ln -s`, `readlink`, `mv`, `rm`, `mktemp`, and `bash -n` deliberately.
