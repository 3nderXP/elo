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
- Modrinth addon search, installation, registry listing, and removal.
- a Gum-powered interactive interface with keyboard navigation.

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
elo
elo --help
```

Running `elo` without arguments opens the interactive interface. The Elo
installer provisions a user-local copy of
[`gum`](https://github.com/charmbracelet/gum), copying an existing executable or
downloading and verifying v0.17.0. The copy remains private under Elo's tools
directory and is never exposed as a global `gum` command. The installer never
uses `sudo` or changes the system package manager. Direct commands remain usable
independently of the interactive interface.

Update to the latest stable release, or select an exact release (including a
pre-release):

```bash
elo update
elo update --version v1.2.0-rc.1
```

After a successful update, Elo keeps the active and immediately previous
releases and removes older managed releases.

Uninstall Elo while preserving instances and downloaded content:

```bash
elo uninstall
```

Use `elo uninstall --purge` only to permanently delete all data under
`~/.elo` as well. Both forms restore original Minecraft directories first.

## Development

```bash
./elo.sh help
./elo.sh init --minecraft-path "$HOME/.minecraft"
./elo.sh instances create fabric-1_21 --version 1.21 --loader fabric
./elo.sh instances activate fabric-1_21
./elo.sh status
./elo.sh addons search sodium --type mod --instance fabric-1_21
./elo.sh addons provider set modrinth --yes
./elo.sh addons install fabric-1_21 sodium --yes
./elo.sh addons list fabric-1_21
./elo.sh addons adopt fabric-1_21 mods/manual-addon.jar --yes
./elo.sh addons remove fabric-1_21 --file mods/manual-addon.jar --yes
./elo.sh instances reset
```

Preview required dependencies without changing files:

```bash
./elo.sh addons install fabric-1_21 sodium --dry-run
```

`addons remove --remove-orphans` offers cleanup based on required dependency edges
known to Elo. Review its list: optional relationships and external addon usage
cannot always be inferred.

Use command-specific help for required fields, defaults, and risks:

```bash
./elo.sh --help
./elo.sh help instances activate
./elo.sh instances reset --help
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
lib/self.sh            safe self-uninstallation
lib/provider.sh        provider routing and addon lifecycle
lib/provider_modrinth.sh public Modrinth API integration
lib/interactive.sh     Gum-powered interactive interface
tests/test_elo.sh      instance-management integration tests
tests/test_install.sh  isolated installer integration test
tests/test_provider.sh offline provider integration tests
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
