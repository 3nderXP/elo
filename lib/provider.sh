#!/usr/bin/env bash

elo_provider_validate_name() {
  [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]] || elo_die "Invalid provider: $1"
}

elo_provider_call() {
  local provider="$1" action="$2" function
  shift 2
  elo_provider_validate_name "$provider" || return
  function="elo_provider_${provider}_${action}"
  if ! declare -F "$function" >/dev/null 2>&1; then
    elo_die "Unsupported provider or action: $provider/$action"
    return 1
  fi
  "$function" "$@"
}

elo_addon_registry() {
  printf '%s/addons.conf\n' "$(elo_instance_dir "$1")"
}

elo_addon_key() {
  printf '%s:%s\n' "$1" "$2"
}

elo_addon_ids() {
  local value
  value="$(elo_kv_get "$(elo_addon_registry "$1")" addon_ids || true)"
  printf '%s' "$value" | tr ',' '\n' | sed '/^$/d'
}

elo_addon_is_registered() {
  local instance="$1" key="$2" existing
  while IFS= read -r existing || [[ -n "$existing" ]]; do
    [[ "$existing" == "$key" ]] && return 0
  done < <(elo_addon_ids "$instance")
  return 1
}

elo_addon_registry_add() {
  local instance="$1" provider="$2" metadata="$3" is_dependency="$4"
  local file key ids project_id
  file="$(elo_addon_registry "$instance")"
  project_id="$(printf '%s' "$metadata" | jq -r '.project_id')"
  key="$(elo_addon_key "$provider" "$project_id")"
  ids="$(elo_kv_get "$file" addon_ids || true)"
  if [[ -n "$ids" ]]; then ids="$ids,$key"; else ids="$key"; fi
  elo_kv_set "$file" addon_ids "$ids"
  elo_kv_set "$file" "${key}_slug" "$(printf '%s' "$metadata" | jq -r '.slug')"
  elo_kv_set "$file" "${key}_name" "$(printf '%s' "$metadata" | jq -r '.name')"
  elo_kv_set "$file" "${key}_version_id" "$(printf '%s' "$metadata" | jq -r '.version_id')"
  elo_kv_set "$file" "${key}_version_number" "$(printf '%s' "$metadata" | jq -r '.version_number')"
  elo_kv_set "$file" "${key}_filename" "$(printf '%s' "$metadata" | jq -r '.filename')"
  elo_kv_set "$file" "${key}_sha512" "$(printf '%s' "$metadata" | jq -r '.sha512 // ""')"
  elo_kv_set "$file" "${key}_type" "$(printf '%s' "$metadata" | jq -r '.type')"
  elo_kv_set "$file" "${key}_is_dependency" "$is_dependency"
}

elo_addon_registry_remove() {
  local instance="$1" key="$2" file ids new_ids="" existing suffix
  file="$(elo_addon_registry "$instance")"
  ids="$(elo_kv_get "$file" addon_ids || true)"
  while IFS= read -r existing || [[ -n "$existing" ]]; do
    [[ -n "$existing" && "$existing" != "$key" ]] || continue
    if [[ -n "$new_ids" ]]; then new_ids="$new_ids,$existing"; else new_ids="$existing"; fi
  done < <(printf '%s' "$ids" | tr ',' '\n')
  elo_kv_set "$file" addon_ids "$new_ids"
  for suffix in slug name version_id version_number filename sha512 type is_dependency; do
    elo_kv_unset "$file" "${key}_$suffix"
  done
}

elo_addon_type_dir() {
  case "$2" in
    mod) printf '%s/mods\n' "$(elo_instance_dir "$1")" ;;
    resourcepack) printf '%s/resourcepacks\n' "$(elo_instance_dir "$1")" ;;
    shader) printf '%s/shaderpacks\n' "$(elo_instance_dir "$1")" ;;
    *) elo_die "Unsupported addon type: $2" ;;
  esac
}

elo_instance_metadata() {
  local instance="$1" field="$2"
  elo_kv_get "$(elo_instance_dir "$instance")/instance.conf" "$field" || true
}

elo_file_sha512() {
  local file="$1"
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 512 "$file" | awk '{print $1}'
  else
    elo_die "sha512sum or shasum is required for addon integrity checks."
  fi
}

elo_text_sha512() {
  if command -v sha512sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha512sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 512 | awk '{print $1}'
  else
    elo_die "sha512sum or shasum is required for addon integrity checks."
  fi
}

elo_addon_key_by_file() {
  local instance="$1" type="$2" filename="$3" key file
  file="$(elo_addon_registry "$instance")"
  while IFS= read -r key || [[ -n "$key" ]]; do
    if [[ "$(elo_kv_get "$file" "${key}_type" || true)" == "$type" && \
      "$(elo_kv_get "$file" "${key}_filename" || true)" == "$filename" ]]; then
      printf '%s\n' "$key"
      return 0
    fi
  done < <(elo_addon_ids "$instance")
  return 1
}

elo_cmd_search() {
  local query="${1:-}" type="" instance="" provider="modrinth" limit=10 version="" loader="" results
  elo_require_initialized || return
  if [[ -z "$query" || "$query" == --* ]]; then elo_die "Usage: elo search <query> [options]"; return; fi
  shift
  while (($# > 0)); do
    case "$1" in
      --type) elo_require_value "$1" "${2:-}" || return; type="$2"; shift 2 ;;
      --instance) elo_require_value "$1" "${2:-}" || return; instance="$2"; shift 2 ;;
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --limit) elo_require_value "$1" "${2:-}" || return; limit="$2"; shift 2 ;;
      *) elo_die "Invalid option for search: $1"; return ;;
    esac
  done
  [[ -z "$type" || "$type" == "mod" || "$type" == "resourcepack" || "$type" == "shader" ]] || { elo_die "Invalid addon type: $type"; return; }
  [[ "$limit" =~ ^[0-9]+$ ]] && ((limit >= 1 && limit <= 100)) || { elo_die "--limit must be between 1 and 100."; return; }
  instance="${instance:-$(elo_active_instance)}"
  if [[ -n "$instance" ]]; then
    elo_require_instance "$instance" || return
    version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
    loader="$(elo_instance_metadata "$instance" LOADER)"
  fi
  results="$(elo_provider_call "$provider" search "$query" "$type" "$version" "$loader" "$limit")" || return
  printf '%-10s %-20s %-12s %-36s %s\n' ID SLUG TYPE NAME DOWNLOADS
  while IFS=$'\t' read -r id slug result_type name downloads; do
    printf '%-10s %-20s %-12s %-36s %s\n' "$id" "$slug" "$result_type" "$name" "$downloads"
  done <<<"$results"
}

ELO_ADDON_INSTALL_VISITED=""
elo_addon_install_recursive() {
  local instance="$1" provider="$2" id_or_slug="$3" is_dependency="$4" requested_version="${5:-}"
  local version loader metadata project_id key type target filename dependencies dep_version dep_project dep_ref
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  metadata="$(elo_provider_call "$provider" resolve "$id_or_slug" "$version" "$loader" "$requested_version")" || return
  project_id="$(printf '%s' "$metadata" | jq -r '.project_id')"
  key="$(elo_addon_key "$provider" "$project_id")"
  [[ "$ELO_ADDON_INSTALL_VISITED" == *"|$key|"* ]] && return 0
  ELO_ADDON_INSTALL_VISITED="$ELO_ADDON_INSTALL_VISITED|$key|"
  if elo_addon_is_registered "$instance" "$key"; then
    if [[ "$is_dependency" == "false" ]]; then elo_kv_set "$(elo_addon_registry "$instance")" "${key}_is_dependency" false; fi
    return 0
  fi
  dependencies="$(elo_provider_call "$provider" get_dependencies "$(printf '%s' "$metadata" | jq -r '.version_id')")" || return
  while IFS=$'\t' read -r dep_version dep_project; do
    dep_ref="${dep_project:-$dep_version}"
    [[ -n "$dep_ref" ]] || continue
    elo_addon_install_recursive "$instance" "$provider" "$dep_ref" true "$dep_version" || return
  done <<<"$dependencies"
  type="$(printf '%s' "$metadata" | jq -r '.type')"
  target="$(elo_addon_type_dir "$instance" "$type")" || return
  filename="$(elo_provider_call "$provider" download "$(printf '%s' "$metadata" | jq -r '.version_id')" "$target")" || return
  metadata="$(printf '%s' "$metadata" | jq -c --arg filename "$filename" '.filename = $filename')"
  local expected_hash actual_hash
  expected_hash="$(printf '%s' "$metadata" | jq -r '.sha512 // ""')"
  actual_hash="$(elo_file_sha512 "$target/$filename")" || return
  if [[ -n "$expected_hash" && "$actual_hash" != "$expected_hash" ]]; then
    rm -- "$target/$filename"
    elo_die "Downloaded addon failed SHA-512 verification: $filename"
    return 1
  fi
  metadata="$(printf '%s' "$metadata" | jq -c --arg sha512 "$actual_hash" '.sha512 = $sha512')"
  elo_addon_registry_add "$instance" "$provider" "$metadata" "$is_dependency"
  elo_info "Installed: $(printf '%s' "$metadata" | jq -r '.name') ($filename)"
}

elo_cmd_install() {
  local instance="${1:-}" addon="${2:-}" provider="modrinth"
  elo_require_initialized || return
  if [[ -z "$instance" || -z "$addon" || "$instance" == --* || "$addon" == --* ]]; then elo_die "Usage: elo install <instance-name> <id-or-slug> [--provider <provider>] [--yes]"; return; fi
  elo_require_instance "$instance" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for install: $1"; return ;;
    esac
  done
  elo_confirm "Install '$addon' and required dependencies into '$instance'?" || { elo_warn "Installation cancelled."; return 1; }
  ELO_ADDON_INSTALL_VISITED=""
  elo_addon_install_recursive "$instance" "$provider" "$addon" false
}

elo_cmd_addons() {
  local instance="${1:-}" key file type filename target expected actual state directory entry entry_type
  elo_require_initialized || return
  [[ -n "$instance" && "$instance" != --* ]] || { elo_die "Usage: elo addons <instance-name>"; return; }
  elo_require_instance "$instance" || return
  (($# == 1)) || { elo_die "Usage: elo addons <instance-name>"; return; }
  file="$(elo_addon_registry "$instance")"
  printf '%-22s %-28s %-12s %-20s %-10s %s\n' SOURCE NAME TYPE VERSION STATE FILE
  while IFS= read -r key || [[ -n "$key" ]]; do
    type="$(elo_kv_get "$file" "${key}_type")"
    filename="$(elo_kv_get "$file" "${key}_filename")"
    expected="$(elo_kv_get "$file" "${key}_sha512" || true)"
    if [[ -z "$filename" || "$filename" == */* || "$filename" == *$'\n'* ]]; then
      state=missing
    else
      target="$(elo_addon_type_dir "$instance" "$type")/$filename" || return
      state=managed
      if [[ ! -f "$target" || -L "$target" ]]; then
        state=missing
      else
        actual="$(elo_file_sha512 "$target")" || return
        [[ -n "$expected" && "$actual" == "$expected" ]] || state=modified
      fi
    fi
    printf '%-22s %-28s %-12s %-20s %-10s %s\n' "$key" \
      "$(elo_kv_get "$file" "${key}_name")" "$type" \
      "$(elo_kv_get "$file" "${key}_version_number")" "$state" "$filename"
  done < <(elo_addon_ids "$instance")

  for entry_type in mod resourcepack shader; do
    directory="$(elo_addon_type_dir "$instance" "$entry_type")"
    shopt -s nullglob dotglob
    for entry in "$directory"/*; do
      [[ -f "$entry" && ! -L "$entry" ]] || continue
      filename="${entry##*/}"
      elo_addon_key_by_file "$instance" "$entry_type" "$filename" >/dev/null && continue
      printf '%-22s %-28s %-12s %-20s %-10s %s\n' - "$filename" "$entry_type" - external "$filename"
    done
    shopt -u nullglob dotglob
  done
}

elo_addon_find_key() {
  local instance="$1" provider="$2" value="$3" key file
  file="$(elo_addon_registry "$instance")"
  while IFS= read -r key || [[ -n "$key" ]]; do
    if [[ "$key" == "$provider:$value" || "$(elo_kv_get "$file" "${key}_slug" || true)" == "$value" ]]; then printf '%s\n' "$key"; return 0; fi
  done < <(elo_addon_ids "$instance")
  return 1
}

elo_cmd_adopt() {
  local instance="${1:-}" relative="${2:-}" type filename target key id hash metadata
  elo_require_initialized || return
  command -v jq >/dev/null 2>&1 || { elo_die "jq is required for addon registry commands."; return; }
  if [[ -z "$instance" || -z "$relative" || "$instance" == --* || "$relative" == --* ]]; then
    elo_die "Usage: elo adopt <instance-name> <relative-path> [--yes]"
    return
  fi
  elo_require_instance "$instance" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for adopt: $1"; return ;;
    esac
  done
  if [[ "$relative" == *$'\n'* || ! "$relative" =~ ^(mods|resourcepacks|shaderpacks)/[^/]+$ ]]; then
    elo_die "Path must be a direct addon path such as mods/example.jar."
    return
  fi
  case "${relative%%/*}" in mods) type=mod ;; resourcepacks) type=resourcepack ;; shaderpacks) type=shader ;; esac
  filename="${relative#*/}"
  [[ "$filename" != "." && "$filename" != ".." ]] || { elo_die "Invalid addon filename."; return; }
  target="$(elo_instance_dir "$instance")/$relative"
  if [[ ! -f "$target" || -L "$target" ]]; then
    elo_die "Only an existing regular addon file can be adopted: $relative"
    return
  fi
  if elo_addon_key_by_file "$instance" "$type" "$filename" >/dev/null; then
    elo_die "Addon file is already managed: $relative"
    return
  fi
  hash="$(elo_file_sha512 "$target")" || return
  id="$(elo_text_sha512 "$relative")" || return
  key="$(elo_addon_key local "$id")"
  if elo_addon_is_registered "$instance" "$key"; then
    elo_die "Registry already contains this addon path: $relative"
    return
  fi
  elo_confirm "Adopt external addon file '$relative' into Elo management?" || { elo_warn "Adoption cancelled."; return 1; }
  metadata="$(jq -cn --arg id "$id" --arg filename "$filename" --arg type "$type" --arg hash "$hash" '{project_id:$id,slug:$filename,name:$filename,version_id:"local",version_number:"local",filename:$filename,sha512:$hash,type:$type}')"
  elo_addon_registry_add "$instance" local "$metadata" false
  elo_info "Adopted: $relative"
}

elo_cmd_uninstall() {
  local instance="${1:-}" addon="" provider="modrinth" key="" file type filename target relative="" expected actual
  elo_require_initialized || return
  if [[ -z "$instance" || "$instance" == --* ]]; then elo_die "Usage: elo uninstall <instance-name> <id-or-slug> [options]"; return; fi
  elo_require_instance "$instance" || return
  shift
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --file) elo_require_value "$1" "${2:-}" || return; relative="$2"; shift 2 ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      --*) elo_die "Invalid option for uninstall: $1"; return ;;
      *) if [[ -n "$addon" ]]; then elo_die "Only one addon may be uninstalled at a time."; return; fi; addon="$1"; shift ;;
    esac
  done
  file="$(elo_addon_registry "$instance")"
  if [[ -n "$relative" ]]; then
    [[ -z "$addon" ]] || { elo_die "Use either <id-or-slug> or --file, not both."; return; }
    if [[ "$relative" == *$'\n'* || ! "$relative" =~ ^(mods|resourcepacks|shaderpacks)/[^/]+$ ]]; then
      elo_die "--file must be a direct addon path such as mods/example.jar."
      return
    fi
    case "${relative%%/*}" in mods) type=mod ;; resourcepacks) type=resourcepack ;; shaderpacks) type=shader ;; esac
    filename="${relative#*/}"
    [[ "$filename" != "." && "$filename" != ".." ]] || { elo_die "Invalid addon filename."; return; }
    target="$(elo_instance_dir "$instance")/$relative"
    key="$(elo_addon_key_by_file "$instance" "$type" "$filename" || true)"
    elo_confirm "Permanently remove exact addon file '$relative' from '$instance'?" || { elo_warn "Uninstallation cancelled."; return 1; }
  else
    [[ -n "$addon" ]] || { elo_die "Provide <id-or-slug> or --file <relative-path>."; return; }
    key="$(elo_addon_find_key "$instance" "$provider" "$addon")" || { elo_die "Addon is not installed: $provider:$addon"; return; }
    type="$(elo_kv_get "$file" "${key}_type")"; filename="$(elo_kv_get "$file" "${key}_filename")"
    if [[ -z "$filename" || "$filename" == */* || "$filename" == *$'\n'* ]]; then elo_die "Registry contains an invalid addon filename."; return; fi
    target="$(elo_addon_type_dir "$instance" "$type")/$filename"
    if [[ -f "$target" && ! -L "$target" ]]; then
      expected="$(elo_kv_get "$file" "${key}_sha512" || true)"
      actual="$(elo_file_sha512 "$target")" || return
      [[ -n "$expected" && "$actual" == "$expected" ]] || { elo_die "Addon file was modified. Use --file with its relative path to remove it explicitly."; return; }
    fi
    elo_confirm "Permanently remove addon '$key'?" || { elo_warn "Uninstallation cancelled."; return 1; }
  fi
  if [[ -L "$target" || ! -f "$target" ]]; then elo_die "Refusing to remove missing or non-regular addon file: $target"; return; fi
  rm -- "$target"
  [[ -z "$key" ]] || elo_addon_registry_remove "$instance" "$key"
  elo_info "Uninstalled: ${key:-$relative}"
  elo_warn "Dependencies are retained; remove confirmed orphans explicitly."
}
