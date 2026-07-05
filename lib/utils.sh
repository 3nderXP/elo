#!/usr/bin/env bash

elo_info() {
  printf 'info: %s\n' "$*"
}

elo_warn() {
  printf 'aviso: %s\n' "$*" >&2
}

elo_error() {
  printf 'erro: %s\n' "$*" >&2
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
    elo_die "$prompt Use --yes em execução não interativa."
    return 1
  fi

  read -r -p "$prompt [s/N] " answer
  [[ "$answer" == "s" || "$answer" == "S" || "$answer" == "sim" || "$answer" == "SIM" ]]
}

elo_validate_instance_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    elo_die "Nome de instância inválido: use apenas letras, números, '_' e '-'."
    return 1
  fi
}

elo_validate_managed_folder() {
  local folder="$1"
  if [[ ! "$folder" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    elo_die "Nome inválido em MANAGED_FOLDERS: $folder"
    return 1
  fi
}

elo_require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    elo_die "A opção $option requer um valor."
    return 1
  fi
}

elo_absolute_existing_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    elo_die "Diretório não encontrado: $path"
    return 1
  fi
  (cd -- "$path" && pwd -P)
}
