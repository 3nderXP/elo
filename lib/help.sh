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
  elo <command> [options]

Commands:
  init      Configure the .minecraft directory to manage
  new       Create an empty instance
  link      Activate an instance and create its symlinks
  switch    Switch the active instance
  reset     Remove managed symlinks and restore original directories
  list      List existing instances
  status    Diagnose the current managed state
  remove    Permanently remove an instance
  help      Show general or command-specific help

Getting started:
  elo init --minecraft-path "$HOME/.minecraft"
  elo new fabric-1_21 --version 1.21 --loader fabric
  elo link fabric-1_21
  elo status
  elo reset

Detailed help:
  elo help <command>
  elo <command> --help

Safety:
  The default link mode backs up original directories.
  Destructive or state-changing operations require confirmation.
  Use --yes only for deliberate non-interactive execution.
EOF
}

elo_help_init() {
  cat <<'EOF'
Usage:
  elo init --minecraft-path <path>

Initialize Elo and select the Minecraft directory to manage.
This command does not move any Minecraft files.

Required fields:
  --minecraft-path <path>
      An existing .minecraft directory. Paths containing spaces are accepted.

Example:
  elo init --minecraft-path "$HOME/.minecraft"
EOF
}

elo_help_new() {
  cat <<'EOF'
Usage:
  elo new <instance-name> [--version <version>] [--loader <loader>]

Create an instance with mods, resourcepacks, shaderpacks, and config folders.

Required fields:
  <instance-name>
      Unique identifier containing only letters, numbers, "_" and "-".

Optional fields:
  --version <version>
      Informational Minecraft version. Default: unknown.
  --loader <loader>
      Informational loader such as fabric, forge, or neoforge. Default: vanilla.

Example:
  elo new fabric-1_21 --version 1.21 --loader fabric
EOF
}

elo_help_link() {
  cat <<'EOF'
Usage:
  elo link <instance-name> [--mode <mode>] [--yes]

Activate an instance by linking .minecraft folders to it.

Required fields:
  <instance-name>
      Name of an existing instance.

Optional fields:
  --mode <mode>
      backup   Preserve real directories before linking. Default.
      replace  Permanently remove real directories after confirmation.
  --yes
      Confirm every prompt. Use only for deliberate automation.

Examples:
  elo link fabric-1_21
  elo link clean-test --mode replace
EOF
}

elo_help_switch() {
  cat <<'EOF'
Usage:
  elo switch <instance-name> [--yes]

Switch managed symlinks from the active instance to another instance.
The original backup remains unchanged.

Required fields:
  <instance-name>
      Name of the instance to activate.

Optional fields:
  --yes
      Confirm the switch without an interactive prompt.

Example:
  elo switch vanilla-1_21
EOF
}

elo_help_reset() {
  cat <<'EOF'
Usage:
  elo reset [--yes]

Stop managing the current instance, remove Elo-owned symlinks, and restore
the real directories preserved in the original backup.

Optional fields:
  --yes
      Confirm the reset without an interactive prompt.

Note:
  Data previously removed with --mode replace cannot be restored.
EOF
}

elo_help_list() {
  cat <<'EOF'
Usage:
  elo list

List every instance with its name, version, loader, and active status.
This command has no fields and does not modify files.
EOF
}

elo_help_status() {
  cat <<'EOF'
Usage:
  elo status

Show the active instance and verify every managed symlink and backup.
Exit with status 1 when a link is missing, broken, or divergent.
This command has no fields and does not modify files.
EOF
}

elo_help_remove() {
  cat <<'EOF'
Usage:
  elo remove <instance-name> [--reset] [--yes]

Permanently remove an instance and all content stored in it.

Required fields:
  <instance-name>
      Name of the instance to remove.

Optional fields:
  --reset
      Restore .minecraft first when the instance is active.
  --yes
      Confirm reset and removal without interactive prompts.

Examples:
  elo remove old-test
  elo remove active-instance --reset
EOF
}

elo_help_help() {
  cat <<'EOF'
Usage:
  elo help [command]

Without a command, show the overview. With a command, show its fields,
defaults, effects, and examples.
EOF
}

elo_help_command() {
  local command="${1:-}"

  case "$command" in
    "" | --help | -h) elo_help_general ;;
    init) elo_help_init ;;
    new) elo_help_new ;;
    link) elo_help_link ;;
    switch) elo_help_switch ;;
    reset) elo_help_reset ;;
    list) elo_help_list ;;
    status) elo_help_status ;;
    remove) elo_help_remove ;;
    help) elo_help_help ;;
    *)
      elo_error "No help is available for command: $command"
      elo_help_general >&2
      return 2
      ;;
  esac
}
