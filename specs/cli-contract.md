# CLI contract

```text
elo init --minecraft-path <path>
elo new <instance-name> [--version <version>] [--loader <loader>]
elo link <instance-name> [--mode backup|replace] [--yes]
elo switch <instance-name> [--yes]
elo reset [--yes]
elo list
elo status
elo remove <instance-name> [--reset] [--yes]
elo update [--version <version>] [--yes]
elo search <query> [--type <type>] [--instance <name>] [--provider <provider>] [--limit <number>]
elo install <instance-name> <id-or-slug> [--provider <provider>] [--yes]
elo addons <instance-name>
elo adopt <instance-name> <mods|resourcepacks|shaderpacks>/<filename> [--yes]
elo uninstall <instance-name> <id-or-slug> [--provider <provider>] [--yes]
elo uninstall <instance-name> --file <mods|resourcepacks|shaderpacks>/<filename> [--yes]
elo help [command]
```

All output must be English. Use `info:`, `warning:`, and `error:` prefixes.
General and command-specific help must explain required fields, defaults,
risks, and examples.

Exit codes: `0` success/consistent, `1` operational failure/inconsistency, and
`2` unknown command. State-changing commands require confirmation; `--yes`
authorizes non-interactive execution.

`elo update` resolves GitHub's latest stable release by default. `--version`
selects an exact SemVer release, including pre-releases; a missing leading `v`
is added. Updates work only from installer-managed releases and activate the
new release only after validation.
After activation, Elo retains the active and immediately previous releases,
then removes older directories that match the managed release layout. Unknown
entries and releases needed for recovery must never be removed.

Addon commands default to public `modrinth`. Search types: `mod`,
`resourcepack`, `shader`; limits: 1 through 100. Install resolves against
instance version and loader, recursively installs required dependencies, never
overwrites files, and records managed files. Uninstall removes only matching
regular registry files; dependencies remain for explicit cleanup.

`elo addons` scans addon directories on demand. Registered files are
`managed`, `modified`, or `missing` based on their stored SHA-512; unregistered
regular files are `external`. Identifier-based uninstall refuses modified
files. `--file` explicitly authorizes one direct relative addon path and also
clears its registry entry when present. Symlinks and nested paths are refused.

`elo adopt` records an external regular file as a local managed addon without
moving or copying it. It stores the file's SHA-512, refuses files already
managed, and requires confirmation. Symlinks and nested paths are refused.
