#!/usr/bin/env bash

elo_info() {
  printf 'info: %s\n' "$*"
}

elo_warn() {
  printf 'warning: %s\n' "$*" >&2
}

elo_error() {
  printf 'error: %s\n' "$*" >&2
}

elo_die() {
  elo_error "$*"
  return 1
}

elo_confirm() {
  local prompt="$1"
  local answer

  if [[ "${ELO_ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    elo_die "$prompt Use --yes for non-interactive execution."
    return 1
  fi

  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

elo_validate_instance_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    elo_die "Invalid instance name: use only letters, numbers, '_' and '-'."
    return 1
  fi
}

elo_validate_managed_folder() {
  local folder="$1"
  if [[ ! "$folder" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    elo_die "Invalid name in MANAGED_FOLDERS: $folder"
    return 1
  fi
}

elo_require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    elo_die "Option $option requires a value."
    return 1
  fi
}

elo_absolute_existing_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    elo_die "Directory not found: $path"
    return 1
  fi
  (cd -- "$path" && pwd -P)
}
