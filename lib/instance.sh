#!/usr/bin/env bash

elo_instance_dir() {
  printf '%s/%s\n' "$ELO_INSTANCES_DIR" "$1"
}

elo_require_instance() {
  local name="$1"
  local directory
  elo_validate_instance_name "$name" || return
  directory="$(elo_instance_dir "$name")"
  if [[ ! -d "$directory" ]]; then
    elo_die "Instância não encontrada: $name"
    return 1
  fi
}

elo_cmd_new() {
  local name="${1:-}" version="desconhecida" loader="vanilla"
  local directory

  elo_require_initialized || return
  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Uso: elo new <nome-instancia> [--version <versão>] [--loader <loader>]"
    return
  fi
  elo_validate_instance_name "$name" || return
  shift

  while (($# > 0)); do
    case "$1" in
      --version)
        elo_require_value "$1" "${2:-}" || return
        version="$2"
        shift 2
        ;;
      --loader)
        elo_require_value "$1" "${2:-}" || return
        loader="$2"
        shift 2
        ;;
      *)
        elo_die "Opção inválida para new: $1"
        return
        ;;
    esac
  done

  directory="$(elo_instance_dir "$name")"
  if [[ -e "$directory" ]]; then
    elo_die "A instância '$name' já existe."
    return
  fi

  mkdir -p -- "$directory"/{mods,resourcepacks,shaderpacks,config}
  : >"$directory/instance.conf"
  elo_kv_set "$directory/instance.conf" INSTANCE_NAME "$name"
  elo_kv_set "$directory/instance.conf" MINECRAFT_VERSION "$version"
  elo_kv_set "$directory/instance.conf" LOADER "$loader"
  elo_kv_set "$directory/instance.conf" CREATED_AT "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  elo_kv_set "$directory/instance.conf" NOTES ""
  elo_info "Instância criada: $name"
}

elo_cmd_list() {
  local active directory name version loader status found=0
  local -a directories

  elo_require_initialized || return
  active="$(elo_active_instance)"

  printf '%-24s %-12s %-12s %s\n' "NOME" "VERSÃO" "LOADER" "STATUS"
  shopt -s nullglob
  directories=("$ELO_INSTANCES_DIR"/*)
  shopt -u nullglob

  for directory in "${directories[@]}"; do
    [[ -d "$directory" ]] || continue
    found=1
    name="${directory##*/}"
    version="$(elo_kv_get "$directory/instance.conf" MINECRAFT_VERSION || printf '%s' '-')"
    loader="$(elo_kv_get "$directory/instance.conf" LOADER || printf '%s' '-')"
    status="-"
    [[ "$name" == "$active" ]] && status="ativa"
    printf '%-24s %-12s %-12s %s\n' "$name" "$version" "$loader" "$status"
  done

  if ((found == 0)); then
    elo_info "Nenhuma instância criada."
  fi
}

elo_cmd_remove() {
  local name="${1:-}" reset=0
  local active directory

  elo_require_initialized || return
  if [[ -z "$name" || "$name" == --* ]]; then
    elo_die "Uso: elo remove <nome-instancia> [--reset] [--yes]"
    return
  fi
  elo_require_instance "$name" || return
  shift

  while (($# > 0)); do
    case "$1" in
      --reset)
        reset=1
        shift
        ;;
      --yes)
        ELO_ASSUME_YES=1
        shift
        ;;
      *)
        elo_die "Opção inválida para remove: $1"
        return
        ;;
    esac
  done

  active="$(elo_active_instance)"
  if [[ "$active" == "$name" ]]; then
    if [[ "$reset" != "1" ]]; then
      elo_die "A instância está ativa. Execute 'elo reset' ou use --reset."
      return
    fi
    elo_cmd_reset || return
  fi

  elo_confirm "Remover permanentemente a instância '$name'?" || {
    elo_warn "Remoção cancelada."
    return 1
  }

  directory="$(elo_instance_dir "$name")"
  rm -rf -- "$directory"
  elo_info "Instância removida: $name"
}
