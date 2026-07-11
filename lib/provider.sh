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

elo_provider_is_available() {
  local provider="$1" action
  elo_provider_validate_name "$provider" || return
  for action in search resolve get_dependencies download; do
    declare -F "elo_provider_${provider}_${action}" >/dev/null 2>&1 || return 1
  done
}

elo_provider_available_names() {
  local provider
  for provider in modrinth; do
    elo_provider_is_available "$provider" && printf '%s\n' "$provider"
  done
}

elo_cmd_provider() {
  local action="${1:-show}" provider
  elo_require_initialized || return
  case "$action" in
    show)
      (($# == 0 || $# == 1)) || { elo_die "Usage: elo provider show"; return; }
      elo_info "Preferred provider: $(elo_preferred_provider)"
      ;;
    list)
      (($# == 1)) || { elo_die "Usage: elo provider list"; return; }
      printf 'AVAILABLE PROVIDERS\n'
      elo_provider_available_names
      ;;
    set)
      provider="${2:-}"
      [[ -n "$provider" ]] || { elo_die "Usage: elo provider set <provider> [--yes]"; return; }
      shift 2
      while (($# > 0)); do
        case "$1" in
          --yes) ELO_ASSUME_YES=1; shift ;;
          *) elo_die "Invalid option for provider set: $1"; return ;;
        esac
      done
      if ! elo_provider_is_available "$provider"; then
        elo_die "Provider is not available: $provider"
        return
      fi
      elo_confirm "Set '$provider' as the preferred provider?" || { elo_warn "Provider change cancelled."; return 1; }
      elo_config_set PREFERRED_PROVIDER "$provider"
      elo_info "Preferred provider: $provider"
      ;;
    *) elo_die "Usage: elo provider show|list|set <provider> [--yes]"; return ;;
  esac
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
  elo_kv_set "$file" "${key}_dependencies" "$(printf '%s' "$metadata" | jq -r '.dependency_keys // ""')"
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
  for suffix in slug name version_id version_number filename sha512 type is_dependency dependencies; do
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

elo_table_value() {
  local value="$1" width="$2"
  value="${value//$'\n'/ }"
  value="${value//$'\t'/ }"
  if ((${#value} > width)); then
    printf '%s...\n' "${value:0:$((width - 3))}"
  else
    printf '%s\n' "$value"
  fi
}

elo_addon_table_row() {
  printf '%-22s %-36s %-12s %-24s %-10s %-51s\n' \
    "$(elo_table_value "$1" 22)" "$(elo_table_value "$2" 36)" \
    "$(elo_table_value "$3" 12)" "$(elo_table_value "$4" 24)" \
    "$(elo_table_value "$5" 10)" "$(elo_table_value "$6" 51)"
}

elo_cmd_search() {
  local query="${1:-}" type="" instance="" provider="" limit=10 version="" loader="" results
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
  provider="${provider:-$(elo_preferred_provider)}"
  if [[ -n "$instance" ]]; then
    elo_require_instance "$instance" || return
    version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
    loader="$(elo_instance_metadata "$instance" LOADER)"
  fi
  results="$(elo_provider_call "$provider" search "$query" "$type" "$version" "$loader" "$limit")" || return
  printf '%-10s %-20s %-12s %-36s %s\n' ID SLUG TYPE NAME DOWNLOADS
  if [[ -z "$results" ]]; then
    elo_info "No addons found."
    return 0
  fi
  while IFS=$'\t' read -r id slug result_type name downloads; do
    printf '%-10s %-20s %-12s %-36s %s\n' "$id" "$slug" "$result_type" "$name" "$downloads"
  done <<<"$results"
}

ELO_ADDON_INSTALL_VISITED=""
ELO_ADDON_LAST_KEY=""
ELO_INSTALL_PLAN_VISITED=""
ELO_INSTALL_PLAN_LINES=""

elo_install_plan_status() {
  local instance="$1" provider="$2" metadata="$3" key type target filename expected actual
  key="$(elo_addon_key "$provider" "$(printf '%s' "$metadata" | jq -r '.project_id')")"
  if elo_addon_is_registered "$instance" "$key"; then
    printf 'already managed\n'
    return
  fi
  type="$(printf '%s' "$metadata" | jq -r '.type')"
  target="$(elo_addon_type_dir "$instance" "$type")" || return
  filename="$(printf '%s' "$metadata" | jq -r '.filename')"
  expected="$(printf '%s' "$metadata" | jq -r '.sha512 // ""')"
  if [[ -e "$target/$filename" || -L "$target/$filename" ]]; then
    if [[ ! -f "$target/$filename" || -L "$target/$filename" ]]; then
      printf 'collision\n'
      return
    fi
    actual="$(elo_file_sha512 "$target/$filename")" || return
    if [[ -n "$expected" && "$actual" == "$expected" ]]; then
      printf 'reuse verified\n'
    else
      printf 'collision\n'
    fi
  else
    printf 'download\n'
  fi
}

elo_install_plan_add_line() {
  local kind="$1" metadata="$2" status="$3" line
  line="$(jq -rn --arg kind "$kind" \
    --arg name "$(printf '%s' "$metadata" | jq -r '.name')" \
    --arg version "$(printf '%s' "$metadata" | jq -r '.version_number')" \
    --arg type "$(printf '%s' "$metadata" | jq -r '.type')" \
    --arg status "$status" '[$kind,$name,$version,$type,$status] | @tsv')"
  ELO_INSTALL_PLAN_LINES="${ELO_INSTALL_PLAN_LINES}${ELO_INSTALL_PLAN_LINES:+$'\n'}$line"
}

elo_install_plan_resolve() {
  local instance="$1" provider="$2" id_or_slug="$3" kind="$4" requested_version="${5:-}"
  local version loader metadata key status dependencies dep_project dep_version dep_ref
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  metadata="$(elo_provider_call "$provider" resolve "$id_or_slug" "$version" "$loader" "$requested_version")" || return
  key="$(elo_addon_key "$provider" "$(printf '%s' "$metadata" | jq -r '.project_id')")"
  [[ "$ELO_INSTALL_PLAN_VISITED" == *"|$key|"* ]] && return 0
  ELO_INSTALL_PLAN_VISITED="$ELO_INSTALL_PLAN_VISITED|$key|"
  status="$(elo_install_plan_status "$instance" "$provider" "$metadata")" || return
  elo_install_plan_add_line "$kind" "$metadata" "$status"
  dependencies="$(elo_provider_call "$provider" get_dependencies "$(printf '%s' "$metadata" | jq -r '.version_id')")" || return
  while IFS=$'\t' read -r dep_project dep_version; do
    [[ "$dep_project" == "-" ]] && dep_project=""
    [[ "$dep_version" == "-" ]] && dep_version=""
    dep_ref="${dep_project:-$dep_version}"
    [[ -n "$dep_ref" ]] || continue
    elo_install_plan_resolve "$instance" "$provider" "$dep_ref" dependency "$dep_version" || return
  done <<<"$dependencies"
}

elo_install_plan_row() {
  printf '%-12s %-34s %-24s %-12s %-18s\n' \
    "$(elo_table_value "$1" 12)" "$(elo_table_value "$2" 34)" \
    "$(elo_table_value "$3" 24)" "$(elo_table_value "$4" 12)" \
    "$(elo_table_value "$5" 18)"
}

elo_install_plan_print() {
  local instance="$1" addon="$2" kind name version type status
  printf 'Installation plan for %s in %s:\n\n' "$addon" "$instance"
  elo_install_plan_row KIND NAME VERSION TYPE ACTION
  printf '%s\n' '--------------------------------------------------------------------------------------------------------'
  while IFS=$'\t' read -r kind name version type status; do
    elo_install_plan_row "$kind" "$name" "$version" "$type" "$status"
  done <<<"$ELO_INSTALL_PLAN_LINES"
}

elo_addon_install_recursive() {
  local instance="$1" provider="$2" id_or_slug="$3" is_dependency="$4" requested_version="${5:-}"
  local version loader metadata project_id key type target filename dependencies dep_version dep_project dep_ref
  local expected_hash actual_hash dependency_keys=""
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  metadata="$(elo_provider_call "$provider" resolve "$id_or_slug" "$version" "$loader" "$requested_version")" || return
  project_id="$(printf '%s' "$metadata" | jq -r '.project_id')"
  key="$(elo_addon_key "$provider" "$project_id")"
  [[ "$ELO_ADDON_INSTALL_VISITED" == *"|$key|"* ]] && return 0
  ELO_ADDON_INSTALL_VISITED="$ELO_ADDON_INSTALL_VISITED|$key|"
  if elo_addon_is_registered "$instance" "$key"; then
    if [[ "$is_dependency" == "false" ]]; then elo_kv_set "$(elo_addon_registry "$instance")" "${key}_is_dependency" false; fi
    ELO_ADDON_LAST_KEY="$key"
    return 0
  fi
  dependencies="$(elo_provider_call "$provider" get_dependencies "$(printf '%s' "$metadata" | jq -r '.version_id')")" || return
  while IFS=$'\t' read -r dep_project dep_version; do
    [[ "$dep_project" == "-" ]] && dep_project=""
    [[ "$dep_version" == "-" ]] && dep_version=""
    dep_ref="${dep_project:-$dep_version}"
    [[ -n "$dep_ref" ]] || continue
    elo_addon_install_recursive "$instance" "$provider" "$dep_ref" true "$dep_version" || return
    if [[ -n "$dependency_keys" ]]; then
      dependency_keys="$dependency_keys,$ELO_ADDON_LAST_KEY"
    else
      dependency_keys="$ELO_ADDON_LAST_KEY"
    fi
  done <<<"$dependencies"
  metadata="$(printf '%s' "$metadata" | jq -c --arg dependencies "$dependency_keys" '.dependency_keys = $dependencies')"
  type="$(printf '%s' "$metadata" | jq -r '.type')"
  target="$(elo_addon_type_dir "$instance" "$type")" || return
  filename="$(printf '%s' "$metadata" | jq -r '.filename')"
  expected_hash="$(printf '%s' "$metadata" | jq -r '.sha512 // ""')"
  if [[ -e "$target/$filename" || -L "$target/$filename" ]]; then
    if [[ ! -f "$target/$filename" || -L "$target/$filename" ]]; then
      elo_die "Refusing to reuse a non-regular addon file: $target/$filename"
      return 1
    fi
    actual_hash="$(elo_file_sha512 "$target/$filename")" || return
    if [[ -z "$expected_hash" || "$actual_hash" != "$expected_hash" ]]; then
      elo_die "Addon file already exists with different or unverifiable content: $target/$filename"
      return 1
    fi
    local existing_key
    existing_key="$(elo_addon_key_by_file "$instance" "$type" "$filename" || true)"
    if [[ -n "$existing_key" && "$existing_key" != "$key" ]]; then
      elo_addon_registry_remove "$instance" "$existing_key"
    fi
    metadata="$(printf '%s' "$metadata" | jq -c --arg sha512 "$actual_hash" '.sha512 = $sha512')"
    elo_addon_registry_add "$instance" "$provider" "$metadata" "$is_dependency"
    elo_warn "Reusing existing verified addon file: $filename"
    ELO_ADDON_LAST_KEY="$key"
    return 0
  fi
  filename="$(elo_provider_call "$provider" download "$(printf '%s' "$metadata" | jq -r '.version_id')" "$target")" || return
  metadata="$(printf '%s' "$metadata" | jq -c --arg filename "$filename" '.filename = $filename')"
  actual_hash="$(elo_file_sha512 "$target/$filename")" || return
  if [[ -n "$expected_hash" && "$actual_hash" != "$expected_hash" ]]; then
    rm -- "$target/$filename"
    elo_die "Downloaded addon failed SHA-512 verification: $filename"
    return 1
  fi
  metadata="$(printf '%s' "$metadata" | jq -c --arg sha512 "$actual_hash" '.sha512 = $sha512')"
  elo_addon_registry_add "$instance" "$provider" "$metadata" "$is_dependency"
  elo_info "Installed: $(printf '%s' "$metadata" | jq -r '.name') ($filename)"
  ELO_ADDON_LAST_KEY="$key"
}

elo_cmd_install() {
  local instance="${1:-}" addon="${2:-}" provider="" dry_run=0
  elo_require_initialized || return
  if [[ -z "$instance" || -z "$addon" || "$instance" == --* || "$addon" == --* ]]; then elo_die "Usage: elo install <instance-name> <id-or-slug> [--provider <provider>] [--yes]"; return; fi
  elo_require_instance "$instance" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for install: $1"; return ;;
    esac
  done
  provider="${provider:-$(elo_preferred_provider)}"
  ELO_INSTALL_PLAN_VISITED=""
  ELO_INSTALL_PLAN_LINES=""
  elo_install_plan_resolve "$instance" "$provider" "$addon" addon || return
  elo_install_plan_print "$instance" "$addon"
  if [[ "$ELO_INSTALL_PLAN_LINES" == *$'\tcollision'* ]]; then
    elo_die "Resolve addon file collisions before installation."
    return 1
  fi
  ((dry_run == 0)) || return 0
  printf '\n'
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
  elo_addon_table_row SOURCE NAME TYPE VERSION STATE FILE
  printf '%s\n' '----------------------------------------------------------------------------------------------------------------------------------------------------------------'
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
    elo_addon_table_row "$key" \
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
      elo_addon_table_row - "$filename" "$entry_type" - external "$filename"
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

elo_addon_hydrate_dependencies() {
  local instance="$1" file key provider version dependencies dep_project dep_version dependency_keys
  file="$(elo_addon_registry "$instance")"
  while IFS= read -r key || [[ -n "$key" ]]; do
    if elo_kv_get "$file" "${key}_dependencies" >/dev/null 2>&1; then
      continue
    fi
    provider="${key%%:*}"
    if [[ "$provider" == "local" ]]; then
      elo_kv_set "$file" "${key}_dependencies" ""
      continue
    fi
    version="$(elo_kv_get "$file" "${key}_version_id" || true)"
    [[ -n "$version" ]] || { elo_die "Cannot resolve dependencies for registry entry: $key"; return; }
    dependencies="$(elo_provider_call "$provider" get_dependencies "$version")" || return
    dependency_keys=""
    while IFS=$'\t' read -r dep_project dep_version; do
      [[ "$dep_project" == "-" ]] && dep_project=""
      [[ "$dep_version" == "-" ]] && dep_version=""
      if [[ -z "$dep_project" && -n "$dep_version" ]]; then
        elo_die "Cannot safely map version-only dependency for registry entry: $key"
        return 1
      fi
      [[ -n "$dep_project" ]] || continue
      if [[ -n "$dependency_keys" ]]; then
        dependency_keys="$dependency_keys,$provider:$dep_project"
      else
        dependency_keys="$provider:$dep_project"
      fi
    done <<<"$dependencies"
    elo_kv_set "$file" "${key}_dependencies" "$dependency_keys"
  done < <(elo_addon_ids "$instance")
}

elo_addon_orphans() {
  local instance="$1" file reachable="" changed=1 key dependency dependencies is_dependency
  file="$(elo_addon_registry "$instance")"
  while IFS= read -r key || [[ -n "$key" ]]; do
    is_dependency="$(elo_kv_get "$file" "${key}_is_dependency" || true)"
    [[ "$is_dependency" == "true" ]] || reachable="$reachable|$key|"
  done < <(elo_addon_ids "$instance")

  while ((changed == 1)); do
    changed=0
    while IFS= read -r key || [[ -n "$key" ]]; do
      [[ "$reachable" == *"|$key|"* ]] || continue
      dependencies="$(elo_kv_get "$file" "${key}_dependencies" || true)"
      while IFS= read -r dependency || [[ -n "$dependency" ]]; do
        [[ -n "$dependency" ]] || continue
        elo_addon_is_registered "$instance" "$dependency" || continue
        if [[ "$reachable" != *"|$dependency|"* ]]; then
          reachable="$reachable|$dependency|"
          changed=1
        fi
      done < <(printf '%s' "$dependencies" | tr ',' '\n')
    done < <(elo_addon_ids "$instance")
  done

  while IFS= read -r key || [[ -n "$key" ]]; do
    is_dependency="$(elo_kv_get "$file" "${key}_is_dependency" || true)"
    if [[ "$is_dependency" == "true" && "$reachable" != *"|$key|"* ]]; then
      printf '%s\n' "$key"
    fi
  done < <(elo_addon_ids "$instance")
}

elo_addon_remove_orphans() {
  local instance="$1" file orphans key count=0 type filename target expected actual name
  file="$(elo_addon_registry "$instance")"
  orphans="$(elo_addon_orphans "$instance")"
  if [[ -z "$orphans" ]]; then
    elo_info "No orphaned dependencies found."
    return 0
  fi
  printf 'Orphaned dependencies:\n'
  while IFS= read -r key || [[ -n "$key" ]]; do
    name="$(elo_kv_get "$file" "${key}_name" || printf '%s' "$key")"
    printf '  %s (%s)\n' "$name" "$key"
    count=$((count + 1))
  done <<<"$orphans"
  elo_confirm "Remove $count orphaned dependencies?" || { elo_warn "Orphan cleanup cancelled."; return 0; }

  while IFS= read -r key || [[ -n "$key" ]]; do
    type="$(elo_kv_get "$file" "${key}_type" || true)"
    filename="$(elo_kv_get "$file" "${key}_filename" || true)"
    if [[ -z "$filename" || "$filename" == */* || "$filename" == *$'\n'* ]]; then
      elo_warn "Keeping orphan with invalid registry filename: $key"
      continue
    fi
    target="$(elo_addon_type_dir "$instance" "$type")/$filename" || return
    if [[ ! -f "$target" || -L "$target" ]]; then
      elo_warn "Keeping orphan with missing or non-regular file: $key"
      continue
    fi
    expected="$(elo_kv_get "$file" "${key}_sha512" || true)"
    actual="$(elo_file_sha512 "$target")" || return
    if [[ -z "$expected" || "$actual" != "$expected" ]]; then
      elo_warn "Keeping modified orphan dependency: $key"
      continue
    fi
    rm -- "$target"
    elo_addon_registry_remove "$instance" "$key"
    elo_info "Removed orphaned dependency: $key"
  done <<<"$orphans"
}

elo_cmd_uninstall() {
  local instance="${1:-}" addon="" provider="" key="" file type filename target relative="" expected actual remove_orphans=0
  elo_require_initialized || return
  if [[ -z "$instance" || "$instance" == --* ]]; then elo_die "Usage: elo uninstall <instance-name> <id-or-slug> [options]"; return; fi
  elo_require_instance "$instance" || return
  shift
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --file) elo_require_value "$1" "${2:-}" || return; relative="$2"; shift 2 ;;
      --remove-orphans) remove_orphans=1; shift ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      --*) elo_die "Invalid option for uninstall: $1"; return ;;
      *) if [[ -n "$addon" ]]; then elo_die "Only one addon may be uninstalled at a time."; return; fi; addon="$1"; shift ;;
    esac
  done
  provider="${provider:-$(elo_preferred_provider)}"
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
  if ((remove_orphans == 1)); then
    elo_addon_hydrate_dependencies "$instance" || return
  fi
  if [[ -L "$target" || ! -f "$target" ]]; then elo_die "Refusing to remove missing or non-regular addon file: $target"; return; fi
  rm -- "$target"
  [[ -z "$key" ]] || elo_addon_registry_remove "$instance" "$key"
  elo_info "Uninstalled: ${key:-$relative}"
  if ((remove_orphans == 1)); then
    elo_addon_remove_orphans "$instance"
  else
    elo_warn "Dependencies are retained; use --remove-orphans for verified cleanup."
  fi
}
