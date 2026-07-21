#!/usr/bin/env bash

elo_help_header() {
  cat <<'EOF'
Elo — Minecraft instance manager

Elo switches mods, resource packs, shaders, and configuration through
symlinks without depending on a specific launcher.

Notation:
  <value>  required
  [value]  optional
EOF
}

elo_help_general() {
  elo_help_header
  cat <<'EOF'

Usage:
  elo
  elo <command> [options]

Commands:
  init        Configure the .minecraft directory to manage
  instances   Create, import, change, activate, list, reset, or remove instances
  addons      Search, install, list, adopt, or remove addons
  status      Diagnose the current managed state
  update      Install a stable or selected Elo release
  uninstall   Uninstall Elo and optionally delete its data
  version     Show the installed Elo version (alias: --version, -v)
  help        Show general or command-specific help

Run without a command to open the Gum-powered interactive interface.

Getting started:
  elo init --minecraft-path "$HOME/.minecraft"
  elo instances create fabric-1_21 --version 1.21 --loader fabric
  elo instances activate fabric-1_21
  elo addons install fabric-1_21 sodium
  elo status

Detailed help:
  elo help <command> [subcommand]
  elo <command> help [subcommand]

Safety:
  Activation backs up original directories by default.
  Destructive or state-changing operations require confirmation.
  Use --yes only for deliberate non-interactive execution.
EOF
}

elo_help_init() {
  cat <<'EOF'
Usage:
  elo init --minecraft-path <path>

Initialize Elo with an existing .minecraft directory. No files are moved.
EOF
}

elo_help_instances() {
  local action="${1:-}"
  case "$action" in
    create) elo_help_instances_create ;;
    import) elo_help_instances_import ;;
    version) elo_help_instances_version ;;
    activate) elo_help_instances_activate ;;
    reset) elo_help_instances_reset ;;
    list) elo_help_instances_list ;;
    remove) elo_help_instances_remove ;;
    "") cat <<'EOF'
Usage:
  elo instances <command> [options]

Commands:
  create     Create an empty instance
  import     Install a local Modrinth .mrpack as a new instance
  version    Change Minecraft version and optionally migrate addons
  activate   Activate or switch to an instance
  reset      Stop management and restore original directories
  list       List existing instances
  remove     Permanently remove an instance

Detailed help:
  elo help instances <command>
  elo instances <command> --help
EOF
      ;;
    *) elo_error "No help is available for instances command: $action"; return 2 ;;
  esac
}

elo_help_instances_import() {
  cat <<'EOF'
Usage:
  elo instances import <name> <file.mrpack> [--yes]

Create an instance from a local Modrinth modpack. Elo validates archive paths,
download hosts, file sizes, and SHA-512 hashes before publishing the instance.
Client overrides inside managed folders are applied. Elo records but does not
install the Minecraft loader declared by the pack.
EOF
}

elo_help_instances_create() {
  cat <<'EOF'
Usage:
  elo instances create <name> [--version <version>] [--loader <loader>]

Create an instance. Names accept letters, numbers, "_", and "-".
Version defaults to "unknown" and loader defaults to "vanilla".
EOF
}

elo_help_instances_activate() {
  cat <<'EOF'
Usage:
  elo instances activate <name> [--mode backup|replace] [--yes]

Activate an instance or switch from the current one. Backup mode preserves
original directories and is the default. Replace mode permanently removes
real destination directories after confirmation.
EOF
}

elo_help_instances_version() {
  cat <<'EOF'
Usage:
  elo instances version <name> <version> [--migrate] [--remove-incompatible] [--dry-run] [--yes]

Analyze every managed addon against a new Minecraft version before changing
the instance. The report marks addons as keep, update, restore, unavailable,
modified, collision, unmanaged, blocked, or external. --dry-run changes nothing. --migrate
downloads and verifies compatible replacements before changing files.
--remove-incompatible moves verified unavailable addons into the migration
backup; modified files and collisions are always kept for manual review.

Without --migrate, addon files stay unchanged after a compatibility warning.
Changing versions can break startup, worlds, configs, and modpack guarantees.
EOF
}

elo_help_instances_reset() {
  cat <<'EOF'
Usage:
  elo instances reset [--yes]

Remove Elo-owned links and restore preserved original directories.
Data previously removed by replace mode cannot be restored.
EOF
}

elo_help_instances_list() {
  cat <<'EOF'
Usage:
  elo instances list

List every instance with its version, loader, and active status.
EOF
}

elo_help_instances_remove() {
  cat <<'EOF'
Usage:
  elo instances remove <name> [--reset] [--yes]

Permanently remove an instance and its contents. An active instance requires
--reset so original Minecraft directories are restored first.
EOF
}

elo_help_addons() {
  local action="${1:-}"
  case "$action" in
    search) elo_help_addons_search ;;
    install) elo_help_addons_install ;;
    list) elo_help_addons_list ;;
    adopt) elo_help_addons_adopt ;;
    remove) elo_help_addons_remove ;;
    provider) elo_help_addons_provider ;;
    "") cat <<'EOF'
Usage:
  elo addons <command> [options]

Commands:
  search      Search provider projects
  install     Install an addon and required dependencies
  list        Scan addons installed in an instance
  adopt       Add an external file to Elo management
  remove      Remove an addon from an instance
  provider    Show or change the preferred provider

Detailed help:
  elo help addons <command>
  elo addons <command> --help
EOF
      ;;
    *) elo_error "No help is available for addons command: $action"; return 2 ;;
  esac
}

elo_help_addons_search() {
  cat <<'EOF'
Usage:
  elo addons search <query> [--type <type>] [--instance <name>] [--provider <provider>] [--limit <number>]

Search public provider projects. Types: mod, modpack, resourcepack, shader. When no
instance is given, the active instance supplies compatibility filters. Its mod
loader filters only mod results; shaders use the game version without inheriting
Fabric, Forge, NeoForge, or Quilt.
EOF
}

elo_help_addons_install() {
  cat <<'EOF'
Usage:
  elo addons install <instance> <id-or-slug|file.mrpack> [--provider <provider>] [--platform iris|optifine] [--dry-run] [--yes]

Resolve a compatible addon and required dependencies. Existing matching files
are verified and reused; different content is never overwritten. Shader
installation requires --platform iris or --platform optifine for an explicit
per-installation compatibility choice. Modpack projects are downloaded through
the provider API; local .mrpack files use the same validated pipeline. A
non-empty target instance produces a conflict warning.
EOF
}

elo_help_addons_list() {
  cat <<'EOF'
Usage:
  elo addons list <instance>

Report managed, modified, missing, and external addon files.
EOF
}

elo_help_addons_adopt() {
  cat <<'EOF'
Usage:
  elo addons adopt <instance> <relative-path> [--yes]

Register an existing regular file directly inside mods, resourcepacks, or
shaderpacks without moving or copying it.
EOF
}

elo_help_addons_remove() {
  cat <<'EOF'
Usage:
  elo addons remove <instance> <id-or-slug> [--provider <provider>] [--remove-orphans] [--yes]
  elo addons remove <instance> --file <relative-path> [--remove-orphans] [--yes]

Remove a verified managed addon. --file explicitly removes an exact external
or modified file. --remove-orphans also offers unreachable dependencies.
EOF
}

elo_help_addons_provider() {
  cat <<'EOF'
Usage:
  elo addons provider [show|list]
  elo addons provider set <provider> [--yes]

Show, list, or change the preferred addon provider. Default: modrinth.
EOF
}

elo_help_status() {
  cat <<'EOF'
Usage:
  elo status

Show the active instance and validate managed symlinks and backup state.
EOF
}

elo_help_update() {
  cat <<'EOF'
Usage:
  elo update [--version <version>] [--yes]

Install and activate the latest stable or an exact SemVer Elo release.
EOF
}

elo_help_version() {
  cat <<'EOF'
Usage:
  elo version
  elo --version
  elo -v

Print the installed Elo version.
EOF
}

elo_help_uninstall() {
  cat <<'EOF'
Usage:
  elo uninstall [--purge] [--yes]

Restore original Minecraft directories and uninstall Elo. Instance data under
ELO_HOME is preserved by default. --purge permanently deletes that data too.
Elo's private Gum copy is removed with the installation. A legacy global Gum
command is preserved for other consumers. This command is available only from
an installed Elo release.
EOF
}

elo_help_help() {
  cat <<'EOF'
Usage:
  elo help [command] [subcommand]
EOF
}

elo_help_command() {
  local command="${1:-}" action="${2:-}"
  case "$command" in
    "" | --help | -h) elo_help_general ;;
    init) elo_help_init ;;
    instances) elo_help_instances "$action" ;;
    addons) elo_help_addons "$action" ;;
    status) elo_help_status ;;
    update) elo_help_update ;;
    uninstall) elo_help_uninstall ;;
    version | --version | -v) elo_help_version ;;
    help) elo_help_help ;;
    *) elo_error "No help is available for command: $command"; elo_help_general >&2; return 2 ;;
  esac
}
