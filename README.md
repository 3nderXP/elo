![Elo](banner.png)

Elo is a modular Bash CLI for managing Minecraft instances independently of
the launcher. It stores instances in `~/.elo` and exposes the active instance
inside `.minecraft` through symlinks.

## Current status

The MVP supports:

- initialization of Elo’s data directory;
- instance creation, listing, and removal;
- instance activation and switching;
- backup and restoration of original `.minecraft` directories;
- detection of external, broken, or divergent symlinks;
- interactive confirmation for state-changing operations.
- stable or version-selected self-updates.

The current target platforms are Linux and macOS with Bash.

## Installation

Install the current version from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/3nderXP/elo/main/install.sh | bash
```

The installer:

- downloads and validates every script before activation;
- installs code under `~/.local/share/elo`;
- creates the `elo` command under `~/.local/bin`;
- does not use `sudo` or initialize `~/.elo`.

If `~/.local/bin` is not in `PATH`, the installer prints the directory that
must be added.

After installation:

```bash
elo init --minecraft-path "$HOME/.minecraft"
elo --help
```

Update to the latest stable release, or select an exact release (including a
pre-release):

```bash
elo update
elo update --version v1.2.0-rc.1
```

After a successful update, Elo keeps the active and immediately previous
releases and removes older managed releases.

## Development

```bash
./elo.sh help
./elo.sh init --minecraft-path "$HOME/.minecraft"
./elo.sh new fabric-1_21 --version 1.21 --loader fabric
./elo.sh link fabric-1_21
./elo.sh status
./elo.sh reset
```

Use command-specific help for required fields, defaults, and risks:

```bash
./elo.sh --help
./elo.sh help link
./elo.sh reset --help
```

Set `ELO_HOME` to isolate data during development or testing.

## Project structure

```text
install.sh             local and GitHub installer
elo.sh                 command parsing and dispatch
lib/utils.sh           messages, confirmation, and validation
lib/help.sh            general and command-specific help
lib/config.sh          config.conf and state.conf persistence
lib/instance.sh        instance lifecycle
lib/link.sh            symlinks, backup, switch, reset, and status
lib/update.sh          stable and version-selected self-updates
tests/test_elo.sh      instance-management integration tests
tests/test_install.sh  isolated installer integration test
```

`elo.sh` is intentionally small. Filesystem logic that can move or remove data
is concentrated in `lib/link.sh`.

## Tests

```bash
./tests/test_elo.sh
./tests/test_install.sh
```

Tests use temporary `ELO_HOME` and `.minecraft` directories and never access
real user data.

## Documentation

- [Required knowledge for LLMs](skills/elo-development/SKILL.md)
- [Git and GitHub specialization](skills/git-github-workflow/SKILL.md)
- [Technical specifications](specs/README.md)
- [Initial project context](initial-feat.md)
