# CLI contract

```text
elo init --minecraft-path <path>
elo instances create <name> [--version <version>] [--loader <loader>]
elo instances import <name> <file.mrpack> [--yes]
elo instances version <name> <version> [--migrate] [--remove-incompatible] [--dry-run] [--yes]
elo instances activate <name> [--mode backup|replace] [--yes]
elo instances reset [--yes]
elo instances list
elo instances remove <name> [--reset] [--yes]
elo addons provider [show|list|set <provider> [--yes]]
elo addons search <query> [--type <type>] [--instance <name>] [--provider <provider>] [--limit <number>]
elo addons install <instance> <id-or-slug|file.mrpack> [--provider <provider>] [--platform iris|optifine] [--dry-run] [--yes]
elo addons list <instance>
elo addons adopt <instance> <mods|resourcepacks|shaderpacks>/<filename> [--yes]
elo addons remove <instance> <id-or-slug> [--provider <provider>] [--remove-orphans] [--yes]
elo addons remove <instance> --file <mods|resourcepacks|shaderpacks>/<filename> [--remove-orphans] [--yes]
elo status
elo update [--version <version>] [--yes]
elo uninstall [--purge] [--yes]
elo version
elo --version
elo -v
elo help [command] [subcommand]
```

`elo` without arguments opens the Gum-powered interactive interface when stdin
and stdout are terminals. The installer supplies Gum in user space when it is
not already available. Supplying a command keeps the direct CLI contract and
remains suitable for automation.

The interactive interface groups the same operations under Instances, Addons,
and System menus. It MUST expose every command and meaningful option in the CLI
contract, including addon search filters, shader platform selection, dry-run
installation, external-file adoption, both addon removal forms, orphan cleanup,
provider management,
activation mode, exact-version updates, purge selection, and command-specific
help. Interactive state changes delegate to the existing command handlers so
their validation and confirmation semantics remain authoritative.

Interactive instance, search-result, installed-addon, and provider lists use a
standard page size of 10 items. Navigation offers `Previous` and `Next` only
when those pages exist, `First` and `Last` for direct boundary jumps, plus
`Back` on every page. Gum initializes the cursor on the last navigation action
when that action remains available. Direct CLI output is not paginated and
remains suitable for pipes and automation.

Interactive lists, link status, and addon installation plans use static
`gum table` rendering with one shared rounded layout and a muted
Minecraft-inspired palette: grass green for focus and
actions, sky blue for structure, and wood brown for selection and context.
Other Gum controls use the same palette. Addon adoption and exact-file removal
use `gum file`, rooted in the selected instance's valid addon directory; the
command handlers still enforce path and file-safety rules. Modpack selection
uses `gum file` rooted at `$HOME`, allowing navigation through the user's file
tree before selecting a `.mrpack`. Its header shows `↑↓` navigate, `→` enter
folder, `←` parent folder, `Enter` select, and `Esc` cancel; picker uses a
automatic scrollable viewport and includes hidden entries.
Every interactive screen renders the installed ASCII logo in wood brown inside
the shared rounded grass-green border and dark theme background. The header has
one blank row above and below the artwork and at least six blank columns on each
side. Its minimum terminal width is calculated from the current artwork width,
both horizontal padding areas, and the border. Narrower terminals use the
compact textual header to prevent horizontal clipping. The renderer passes the
logo to Gum as one argument so structural leading and trailing spaces are
preserved.

Before the first interactive page is shown, Gum displays a loading spinner.
Search, instance, and provider lists build a fresh session snapshot and derive
the current and adjacent pages from it by numeric index. Addon listing first
builds a cheap inventory, validates only the current page, and prefetches the
next page in a background worker while visited pages remain cached. If a page
is requested before its worker finishes, the spinner remains visible until it
is ready. Interactive provider search also loads pages lazily using provider
offsets and total-hit metadata; its selected page size does not cap the total
number of browsable results. A new list operation invalidates the prior cache,
and leaving the interactive process stops workers and removes its temporary
files.

All output must be English. Use `info:`, `warning:`, and `error:` prefixes.
General and command-specific help must explain required fields, defaults,
risks, and examples.

Exit codes: `0` success/consistent, `1` operational failure/inconsistency, and
`2` unknown command. State-changing commands require confirmation; `--yes`
authorizes non-interactive execution. Flat instance and addon commands do not
exist; unknown legacy forms return exit code `2` without compatibility aliases.

`elo version` (aliases `--version` and `-v`) prints the installed Elo version
and takes no options. Outside an installer-managed release it prints `unknown`.

Opening the interactive interface (`elo` with no arguments) always checks for
a newer stable release, caching the result for 24 hours. Its header renders
the installed version (or `development` outside an installer-managed release)
in its own small rounded-border badge above the main header box, top-left
aligned, plus an update notice when a newer release exists. Direct CLI
commands never perform this check implicitly.

After a successful update from the interactive interface's System menu, Elo
restarts itself in place (`exec`) using the original invocation, so the new
release's code is active immediately without leaving the running session. A
cancelled or failed update never restarts the process. Direct CLI
`elo update` never restarts the invoking shell; the next command already runs
the new release.

`elo update` resolves GitHub's latest stable release by default. `--version`
selects an exact SemVer release, including pre-releases; a missing leading `v`
is added. Updates work only from installer-managed releases and activate the
new release only after validation.
After activation, Elo retains the active and immediately previous releases,
then removes older directories that match the managed release layout. Unknown
entries and releases needed for recovery must never be removed.

`elo addons` commands default to public `modrinth`. Search types: `mod`,
`modpack`, `resourcepack`, `shader`; limits: 1 through 100. Install uses type-specific
instance compatibility, recursively installs required dependencies, never
overwrites files, and records managed files. Remove deletes only matching
regular registry files; dependencies remain for explicit cleanup.

`elo addons provider` shows the preferred provider, `list` lists available
provider modules, and `set` persists a validated preference after confirmation.
Search, install, and identifier-based removal use it unless their explicit
`--provider` option overrides it. The initial preference is `modrinth`.

`instances version` classifies the change as an upgrade, downgrade, or opaque
version change and analyzes every managed addon before confirmation. Migration
downloads and verifies all compatible replacements before publishing changes,
keeps modified or colliding files, and stores replaced files plus registry and
instance metadata in a timestamped `.elo-migrations` backup. Without
`--migrate`, only instance metadata changes and all addon files remain.

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

Addon listing reads the registry once, builds a linear reverse file index, and
caches managed-file integrity results by expected hash plus device, inode,
size, modification time, and change time. Unchanged fingerprints reuse their
display state; new or changed fingerprints recalculate SHA-512. Removal and
orphan cleanup always verify current file content independently of this derived
cache.

Instance loader filters apply only to mod searches and mod version resolution.
Resource packs resolve with Modrinth's `minecraft` loader classification.
Shaders retain the instance's game-version filter but do not inherit its mod
loader. Shader installation requires `--platform iris|optifine` for an explicit
per-installation choice. The interactive flow requires the same Iris or OptiFine
selection without persisting a global shader platform on the instance.

Search prints `info: No addons found.` when provider results are empty.

`instances import` accepts a local Modrinth format version 1 archive and creates
one new client instance atomically. It validates every archive and index path,
allows HTTPS downloads only from Modrinth's documented host set, verifies
declared sizes and SHA-512 hashes, skips client-unsupported files and server
overrides, and applies `overrides` followed by `client-overrides`. Paths outside
Elo-managed folders in the index are refused; such override files are reported
and ignored because Elo cannot activate them. Optional client files are
included. Existing instances and files are never overwritten. Loader metadata
is recorded, but the loader itself is not installed.

`addons install` accepts Modrinth modpack project IDs and slugs. It resolves a
compatible version through the provider API, downloads and verifies its
`.mrpack`, then installs indexed client files and overrides into the chosen
instance. A local `.mrpack` path uses the same pipeline. A non-empty target
instance always emits a warning recommending an empty instance before collision
checks; an empty instance emits no warning and adopts the pack's Minecraft and
loader metadata. Existing paths are never overwritten.

Modpack installation reports archive download, per-file progress, and override
application stages. The plan labels indexed files as `Files to download` until
their verified downloads complete.

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
