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
elo provider [show|list|set <provider> [--yes]]
elo search <query> [--type <type>] [--instance <name>] [--provider <provider>] [--limit <number>]
elo install <instance-name> <id-or-slug> [--provider <provider>] [--dry-run] [--yes]
elo addons <instance-name>
elo adopt <instance-name> <mods|resourcepacks|shaderpacks>/<filename> [--yes]
elo uninstall <instance-name> <id-or-slug> [--provider <provider>] [--remove-orphans] [--yes]
elo uninstall <instance-name> --file <mods|resourcepacks|shaderpacks>/<filename> [--remove-orphans] [--yes]
elo help [command]
```

`elo` without arguments opens the Gum-powered interactive interface when stdin
and stdout are terminals. The installer supplies Gum in user space when it is
not already available. Supplying a command keeps the direct CLI contract and
remains suitable for automation.

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

`elo provider` shows the preferred provider, `list` lists available provider
modules, and `set` persists a validated preference after confirmation. Search,
install, and identifier-based uninstall use it unless their explicit
`--provider` option overrides it. The initial preference is `modrinth`.

Install reuses an unregistered regular file only when its SHA-512 matches the
provider metadata, emits a warning, and records it as managed. A different or
unverifiable file remains a blocking collision; symlinks are never reused.
Before confirmation, install displays the root addon and recursively resolved
required dependencies with `download`, `already managed`, `reuse verified`, or
`collision` actions. `--dry-run` prints this plan without filesystem changes.
`--yes` skips confirmation but does not hide the plan.

`elo addons` scans addon directories on demand. Registered files are
`managed`, `modified`, or `missing` based on their stored SHA-512; unregistered
regular files are `external`. Identifier-based uninstall refuses modified
files. `--file` explicitly authorizes one direct relative addon path and also
clears its registry entry when present. Symlinks and nested paths are refused.
Output uses a fixed 160-character table; values exceeding column widths end in
`...`.

Search prints `info: No addons found.` when provider results are empty.
`uninstall --remove-orphans` computes reachability from every remaining direct
addon using persisted required-dependency edges. Only unreachable dependency
entries with matching SHA-512 are offered for removal. Modified, missing,
irregular, or incompletely mapped entries are retained or abort cleanup safely.
Optional provider relationships and usage by external addons may be unknown,
so users MUST review the proposed list before confirming cleanup.

`elo adopt` records an external regular file as a local managed addon without
moving or copying it. It stores the file's SHA-512, refuses files already
managed, and requires confirmation. Symlinks and nested paths are refused.
