# CLI contract

```text
elo init --minecraft-path <path>
elo instances create <name> [--version <version>] [--loader <loader>]
elo instances activate <name> [--mode backup|replace] [--yes]
elo instances reset [--yes]
elo instances list
elo instances remove <name> [--reset] [--yes]
elo addons provider [show|list|set <provider> [--yes]]
elo addons search <query> [--type <type>] [--instance <name>] [--provider <provider>] [--limit <number>]
elo addons install <instance> <id-or-slug> [--provider <provider>] [--dry-run] [--yes]
elo addons list <instance>
elo addons adopt <instance> <mods|resourcepacks|shaderpacks>/<filename> [--yes]
elo addons remove <instance> <id-or-slug> [--provider <provider>] [--remove-orphans] [--yes]
elo addons remove <instance> --file <mods|resourcepacks|shaderpacks>/<filename> [--remove-orphans] [--yes]
elo status
elo update [--version <version>] [--yes]
elo uninstall [--purge] [--yes]
elo help [command] [subcommand]
```

`elo` without arguments opens the Gum-powered interactive interface when stdin
and stdout are terminals. The installer supplies Gum in user space when it is
not already available. Supplying a command keeps the direct CLI contract and
remains suitable for automation.

The interactive interface groups the same operations under Instances, Addons,
and System menus. It MUST expose every command and meaningful option in the CLI
contract, including addon search filters, dry-run installation, external-file
adoption, both addon removal forms, orphan cleanup, provider management,
activation mode, exact-version updates, purge selection, and command-specific
help. Interactive state changes delegate to the existing command handlers so
their validation and confirmation semantics remain authoritative.

Interactive instance, search-result, installed-addon, and provider lists use a
standard page size of 10 items. Navigation offers `Previous` and `Next` only
when those pages exist, plus `Back` on every page. Search requests up to 50
results by default so navigation can span multiple pages. Direct CLI output is
not paginated and remains suitable for pipes and automation.

Before the first interactive page is shown, Gum displays a loading spinner.
Search, instance, and provider lists build a fresh session snapshot and derive
the current and adjacent pages from it by numeric index. Addon listing first
builds a cheap inventory, validates only the current page, and prefetches the
next page in a background worker while visited pages remain cached. If a page
is requested before its worker finishes, the spinner remains visible until it
is ready. A new list operation invalidates the prior cache, and leaving the
interactive process stops workers and removes its temporary files.

All output must be English. Use `info:`, `warning:`, and `error:` prefixes.
General and command-specific help must explain required fields, defaults,
risks, and examples.

Exit codes: `0` success/consistent, `1` operational failure/inconsistency, and
`2` unknown command. State-changing commands require confirmation; `--yes`
authorizes non-interactive execution. Flat instance and addon commands do not
exist; unknown legacy forms return exit code `2` without compatibility aliases.

`elo update` resolves GitHub's latest stable release by default. `--version`
selects an exact SemVer release, including pre-releases; a missing leading `v`
is added. Updates work only from installer-managed releases and activate the
new release only after validation.
After activation, Elo retains the active and immediately previous releases,
then removes older directories that match the managed release layout. Unknown
entries and releases needed for recovery must never be removed.

`elo addons` commands default to public `modrinth`. Search types: `mod`,
`resourcepack`, `shader`; limits: 1 through 100. Install resolves against
instance version and loader, recursively installs required dependencies, never
overwrites files, and records managed files. Remove deletes only matching
regular registry files; dependencies remain for explicit cleanup.

`elo addons provider` shows the preferred provider, `list` lists available
provider modules, and `set` persists a validated preference after confirmation.
Search, install, and identifier-based removal use it unless their explicit
`--provider` option overrides it. The initial preference is `modrinth`.

Install reuses an unregistered regular file only when its SHA-512 matches the
provider metadata, emits a warning, and records it as managed. A different or
unverifiable file remains a blocking collision; symlinks are never reused.
Before confirmation, install displays the root addon and recursively resolved
required dependencies with `download`, `already managed`, `reuse verified`, or
`collision` actions. `--dry-run` prints this plan without filesystem changes.
`--yes` skips confirmation but does not hide the plan.

`elo addons list` scans addon directories on demand. Registered files are
`managed`, `modified`, or `missing` based on their stored SHA-512; unregistered
regular files are `external`. Identifier-based removal refuses modified
files. `--file` explicitly authorizes one direct relative addon path and also
clears its registry entry when present. Symlinks and nested paths are refused.
Output uses a fixed 160-character table; values exceeding column widths end in
`...`.

Search prints `info: No addons found.` when provider results are empty.
`addons remove --remove-orphans` computes reachability from every remaining
direct addon using persisted required-dependency edges. Only unreachable dependency
entries with matching SHA-512 are offered for removal. Modified, missing,
irregular, or incompletely mapped entries are retained or abort cleanup safely.
Optional provider relationships and usage by external addons may be unknown,
so users MUST review the proposed list before confirming cleanup.

`elo addons adopt` records an external regular file as a local managed addon
without moving or copying it. It stores the file's SHA-512, refuses files already
managed, and requires confirmation. Symlinks and nested paths are refused.

`elo uninstall` works only from an installer-managed active release. It first
restores original Minecraft directories, removes only installer-owned command
links and installation data, and preserves `ELO_HOME` by default. `--purge`
also permanently removes `ELO_HOME`. Gum lives inside the private Elo tools
directory and is not exposed as a global command. If self-uninstall finds a
legacy global Gum symlink into that directory, it preserves a standalone copy
so other consumers do not break.
