# Elo — Initial MVP Context

## Purpose

Elo is a Bash CLI that manages Minecraft instances without requiring a
specific launcher. Launchers continue reading normal `.minecraft` paths while
Elo redirects selected folders to the active instance through symlinks.

The MVP manages:

- `mods`;
- `resourcepacks`;
- `shaderpacks`;
- `config`.

It does not download mods, install loaders, or manage Minecraft versions.

## Runtime data

```text
~/.elo/
├── config.conf
├── state.conf
├── instances/
│   └── <instance-name>/
│       ├── instance.conf
│       ├── mods/
│       ├── resourcepacks/
│       ├── shaderpacks/
│       └── config/
└── backups/
    └── original/
        └── <folder>.bak/
```

Original `.minecraft` folders belong to the configured Minecraft directory,
not to an Elo instance. Switching instances must never replace the original
backup.

## MVP commands

```text
elo init --minecraft-path <path>
elo new <instance-name> [--version <version>] [--loader <loader>]
elo link <instance-name> [--mode backup|replace] [--yes]
elo switch <instance-name> [--yes]
elo reset [--yes]
elo list
elo status
elo remove <instance-name> [--reset] [--yes]
```

### `init`

Create Elo’s runtime structure and record the target `.minecraft` path.

### `new`

Create an instance and its managed folders. Instance names accept only
`[a-zA-Z0-9_-]`.

### `link`

Activate an instance. In default `backup` mode, move real `.minecraft`
directories to `backups/original/` before creating absolute symlinks.

`replace` mode may remove real directories only after explicit confirmation.
Removed data cannot be restored.

### `switch`

Replace only Elo-owned symlinks while preserving the original backup.

### `reset`

Remove Elo-owned symlinks and restore real directories that existed before
management began. Paths originally absent remain absent.

### `list` and `status`

List instances and diagnose links, backups, and divergent state.

### `remove`

Permanently remove an inactive instance after confirmation. An active instance
must be reset first.

## Persistence

Configuration uses `KEY=VALUE` `.conf` files parsed as data. These files must
never be executed with `source` or `eval`.

Example `config.conf`:

```text
MINECRAFT_PATH=/home/user/.minecraft
ACTIVE_INSTANCE=skyblock
MANAGED_FOLDERS=mods resourcepacks shaderpacks config
```

Example `state.conf`:

```text
LINKED_mods=skyblock
ORIGINAL_mods=backed_up
ORIGINAL_resourcepacks=absent
ORIGINAL_config=removed
```

Original states:

- `backed_up`: a real directory was preserved;
- `absent`: the path did not exist;
- `removed`: deletion was explicitly authorized.

## Safety requirements

- Never remove unknown user data.
- Never overwrite an original backup.
- Validate symlink ownership against `state.conf`.
- Detect broken and divergent links.
- Keep `link` idempotent.
- Validate all names used in paths.
- Preserve recoverable state when an operation fails.
- Use absolute symlink targets.

## Implementation

The project is implemented entirely as Bash `.sh` files:

```text
install.sh
elo.sh
lib/
├── utils.sh
├── help.sh
├── config.sh
├── instance.sh
└── link.sh
```

The initial target is Linux and macOS. Windows support is outside the MVP.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/3nderXP/elo/main/install.sh | bash
```

The installer deploys code and creates the `elo` command. Runtime
initialization remains the responsibility of `elo init`.
