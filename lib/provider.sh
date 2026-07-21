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
  for action in search search_page project_type resolve get_dependencies download; do
    declare -F "elo_provider_${provider}_${action}" >/dev/null 2>&1 || return 1
  done
}

elo_search_page() {
  local provider="$1" query="$2" type="$3" instance="$4" limit="$5" offset="$6"
  local version="" loader=""
  elo_require_initialized || return
  [[ -z "$type" || "$type" == "mod" || "$type" == "resourcepack" || "$type" == "shader" || "$type" == "modpack" ]] || {
    elo_die "Invalid addon type: $type"
    return 1
  }
  [[ "$limit" =~ ^[0-9]+$ ]] && ((limit >= 1 && limit <= 100)) || {
    elo_die "Page size must be between 1 and 100."
    return 1
  }
  [[ "$offset" =~ ^[0-9]+$ ]] || {
    elo_die "Search offset must be a non-negative integer."
    return 1
  }
  if [[ -n "$instance" ]]; then
    elo_require_instance "$instance" || return
    version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
    loader="$(elo_instance_metadata "$instance" LOADER)"
  fi
  elo_provider_call "$provider" search_page \
    "$query" "$type" "$version" "$loader" "$limit" "$offset"
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
      (($# == 0 || $# == 1)) || { elo_die "Usage: elo addons provider show"; return; }
      elo_info "Preferred provider: $(elo_preferred_provider)"
      ;;
    list)
      (($# == 1)) || { elo_die "Usage: elo addons provider list"; return; }
      printf 'AVAILABLE PROVIDERS\n'
      elo_provider_available_names
      ;;
    set)
      provider="${2:-}"
      [[ -n "$provider" ]] || { elo_die "Usage: elo addons provider set <provider> [--yes]"; return; }
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
    *) elo_die "Usage: elo addons provider show|list|set <provider> [--yes]"; return ;;
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
  elo_addon_cache_invalidate "$instance" "$key" || true
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
  elo_addon_cache_invalidate "$instance" "$key" || true
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

elo_file_fingerprint() {
  local file="$1" fingerprint
  if fingerprint="$(stat -c '%d:%i:%s:%Y:%Z' "$file" 2>/dev/null)"; then
    printf '%s\n' "$fingerprint"
  elif fingerprint="$(stat -f '%d:%i:%z:%m:%c' "$file" 2>/dev/null)"; then
    printf '%s\n' "$fingerprint"
  else
    elo_die "Could not read addon file metadata: $file"
    return 1
  fi
}

elo_addon_cache_instance_dir() {
  printf '%s/%s\n' "$ELO_ADDON_CACHE_DIR" "$1"
}

elo_addon_cache_file() {
  local instance="$1" key="$2" cache_id
  cache_id="$(elo_text_sha512 "$key")" || return
  printf '%s/%s.conf\n' "$(elo_addon_cache_instance_dir "$instance")" "$cache_id"
}

elo_addon_cache_invalidate() {
  local instance="$1" key="$2" cache_file
  cache_file="$(elo_addon_cache_file "$instance" "$key")" || return
  rm -f -- "$cache_file"
}

elo_addon_cache_write() {
  local instance="$1" key="$2" expected="$3" fingerprint="$4" actual="$5" state="$6"
  local cache_file temporary
  cache_file="$(elo_addon_cache_file "$instance" "$key")" || return
  mkdir -p -- "$(dirname -- "$cache_file")"
  temporary="$(mktemp "${cache_file}.tmp.XXXXXX")"
  {
    printf 'CACHE_VERSION=1\n'
    printf 'ADDON_KEY=%s\n' "$key"
    printf 'EXPECTED_SHA512=%s\n' "$expected"
    printf 'FINGERPRINT=%s\n' "$fingerprint"
    printf 'ACTUAL_SHA512=%s\n' "$actual"
    printf 'STATE=%s\n' "$state"
  } >"$temporary"
  mv -- "$temporary" "$cache_file"
}

elo_addon_cached_state() {
  local instance="$1" key="$2" expected="$3" target="$4"
  local cache_file fingerprint="missing" actual="" state=missing
  cache_file="$(elo_addon_cache_file "$instance" "$key")" || return
  if [[ -f "$target" && ! -L "$target" ]]; then
    fingerprint="$(elo_file_fingerprint "$target")" || return
  fi
  if [[ -f "$cache_file" && \
    "$(elo_kv_get "$cache_file" CACHE_VERSION || true)" == "1" && \
    "$(elo_kv_get "$cache_file" ADDON_KEY || true)" == "$key" && \
    "$(elo_kv_get "$cache_file" EXPECTED_SHA512 || true)" == "$expected" && \
    "$(elo_kv_get "$cache_file" FINGERPRINT || true)" == "$fingerprint" ]]; then
    state="$(elo_kv_get "$cache_file" STATE || true)"
    if [[ "$state" == "managed" || "$state" == "modified" || "$state" == "missing" ]]; then
      printf '%s\n' "$state"
      return 0
    fi
  fi
  if [[ "$fingerprint" != "missing" ]]; then
    if [[ -n "$expected" ]]; then
      actual="$(elo_file_sha512 "$target")" || return
      if [[ "$actual" == "$expected" ]]; then state=managed; else state=modified; fi
    else
      state=modified
    fi
  fi
  elo_addon_cache_write "$instance" "$key" "$expected" "$fingerprint" "$actual" "$state" || return
  printf '%s\n' "$state"
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
  if [[ -z "$query" || "$query" == --* ]]; then elo_die "Usage: elo addons search <query> [options]"; return; fi
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
  [[ -z "$type" || "$type" == "mod" || "$type" == "resourcepack" || "$type" == "shader" || "$type" == "modpack" ]] || { elo_die "Invalid addon type: $type"; return; }
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
  local instance="$1" provider="$2" id_or_slug="$3" kind="$4" requested_version="${5:-}" platform="${6:-}"
  local version loader metadata key status dependencies dep_project dep_version dep_ref
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  metadata="$(elo_provider_call "$provider" resolve "$id_or_slug" "$version" "$loader" "$requested_version" "$platform")" || return
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
  if [[ "${ELO_UI_ACTIVE:-0}" == "1" ]] && declare -F elo_ui_install_plan_table >/dev/null 2>&1; then
    elo_ui_install_plan_table "$instance" "$addon" "$ELO_INSTALL_PLAN_LINES"
    return
  fi
  printf 'Installation plan for %s in %s:\n\n' "$addon" "$instance"
  elo_install_plan_row KIND NAME VERSION TYPE ACTION
  printf '%s\n' '--------------------------------------------------------------------------------------------------------'
  while IFS=$'\t' read -r kind name version type status; do
    elo_install_plan_row "$kind" "$name" "$version" "$type" "$status"
  done <<<"$ELO_INSTALL_PLAN_LINES"
}

elo_addon_install_recursive() {
  local instance="$1" provider="$2" id_or_slug="$3" is_dependency="$4" requested_version="${5:-}" platform="${6:-}"
  local version loader metadata project_id key type target filename dependencies dep_version dep_project dep_ref
  local expected_hash actual_hash dependency_keys=""
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  metadata="$(elo_provider_call "$provider" resolve "$id_or_slug" "$version" "$loader" "$requested_version" "$platform")" || return
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
  elo_progress "Addon" 0 1 "$(printf '%s' "$metadata" | jq -r '.filename // .name')"
  filename="$(elo_provider_call "$provider" download "$(printf '%s' "$metadata" | jq -r '.version_id')" "$target")" || return
  elo_progress "Addon" 1 1 "$filename"
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
  local instance="${1:-}" addon="${2:-}" provider="" platform="" dry_run=0 project_type
  elo_require_initialized || return
  if [[ -z "$instance" || -z "$addon" || "$instance" == --* || "$addon" == --* ]]; then elo_die "Usage: elo addons install <instance> <id-or-slug|file.mrpack> [options]"; return; fi
  elo_require_instance "$instance" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --platform) elo_require_value "$1" "${2:-}" || return; platform="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for install: $1"; return ;;
    esac
  done
  [[ -z "$platform" || "$platform" == "iris" || "$platform" == "optifine" ]] || {
    elo_die "--platform must be iris or optifine."
    return 1
  }
  provider="${provider:-$(elo_preferred_provider)}"
  if [[ "$addon" == *.mrpack || -f "$addon" || -L "$addon" ]]; then
    [[ -z "$platform" ]] || { elo_die "--platform cannot be used with a modpack."; return; }
    elo_mrpack_install_into_instance "$instance" "$addon" "$dry_run" local ""
    return
  fi
  project_type="$(elo_provider_call "$provider" project_type "$addon")" || return
  if [[ "$project_type" == "modpack" ]]; then
    [[ -z "$platform" ]] || { elo_die "--platform cannot be used with a modpack."; return; }
    elo_mrpack_install_from_provider "$instance" "$provider" "$addon" "$dry_run"
    return
  fi
  ELO_INSTALL_PLAN_VISITED=""
  ELO_INSTALL_PLAN_LINES=""
  elo_install_plan_resolve "$instance" "$provider" "$addon" addon "" "$platform" || return
  elo_install_plan_print "$instance" "$addon"
  if [[ "$ELO_INSTALL_PLAN_LINES" == *$'\tcollision'* ]]; then
    elo_die "Resolve addon file collisions before installation."
    return 1
  fi
  ((dry_run == 0)) || return 0
  printf '\n'
  elo_confirm "Install '$addon' and required dependencies into '$instance'?" || { elo_warn "Installation cancelled."; return 1; }
  ELO_ADDON_INSTALL_VISITED=""
  elo_addon_install_recursive "$instance" "$provider" "$addon" false "" "$platform"
}

elo_version_relation() {
  local current="$1" target="$2"
  if [[ "$current" == "$target" ]]; then
    printf 'same\n'
    return
  fi
  if [[ "$current" =~ ^[0-9]+([.][0-9]+)*$ && "$target" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
    awk -v current="$current" -v target="$target" '
      BEGIN {
        current_count = split(current, current_part, ".")
        target_count = split(target, target_part, ".")
        count = current_count > target_count ? current_count : target_count
        for (i = 1; i <= count; i++) {
          current_value = current_part[i] + 0
          target_value = target_part[i] + 0
          if (target_value > current_value) { print "upgrade"; exit }
          if (target_value < current_value) { print "downgrade"; exit }
        }
        print "same"
      }'
  else
    printf 'change\n'
  fi
}

elo_migration_safe_field() {
  local value="$1"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

elo_migration_plan_add() {
  local state="$1" key="$2" name="$3" current="$4" target="$5" type="$6"
  local old_filename="$7" new_filename="$8" metadata="$9"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$state" "$key" "$(elo_migration_safe_field "$name")" \
    "$(elo_migration_safe_field "$current")" "$(elo_migration_safe_field "$target")" \
    "$type" "$(elo_migration_safe_field "$old_filename")" \
    "$(elo_migration_safe_field "$new_filename")" "$metadata"
}

elo_migration_shader_platform() {
  local provider="$1" project_id="$2" old_version="$3" loader="$4" metadata platforms
  metadata="$(elo_provider_call "$provider" resolve "$project_id" unknown "$loader" \
    "$old_version" "" 2>/dev/null || true)"
  [[ -n "$metadata" ]] || return 0
  platforms="$(printf '%s' "$metadata" | jq -r '.platforms[]?' 2>/dev/null || true)"
  if [[ "$platforms" == *iris* ]]; then printf 'iris\n'
  elif [[ "$platforms" == *optifine* ]]; then printf 'optifine\n'
  fi
}

elo_migration_plan_build() {
  local instance="$1" target_version="$2" file loader key provider project_id name
  local current_version current_version_id type old_filename expected target_metadata=""
  local target_version_id target_version_number new_filename target_type platform="" error_file
  local target target_dir target_hash actual physical_state inventory_state inventory_type inventory_file
  file="$(elo_addon_registry "$instance")"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  error_file="$(mktemp "${TMPDIR:-/tmp}/elo-migration-errors.XXXXXX")" || return

  while IFS= read -r key || [[ -n "$key" ]]; do
    [[ -n "$key" ]] || continue
    provider="${key%%:*}"
    project_id="${key#*:}"
    name="$(elo_kv_get "$file" "${key}_name" || true)"
    current_version="$(elo_kv_get "$file" "${key}_version_number" || true)"
    current_version_id="$(elo_kv_get "$file" "${key}_version_id" || true)"
    type="$(elo_kv_get "$file" "${key}_type" || true)"
    old_filename="$(elo_kv_get "$file" "${key}_filename" || true)"
    expected="$(elo_kv_get "$file" "${key}_sha512" || true)"
    target_dir="$(elo_addon_type_dir "$instance" "$type" 2>/dev/null || true)"
    if [[ -z "$target_dir" ]]; then
      elo_migration_plan_add unmanaged "$key" "$name" "$current_version" - \
        "$type" "$old_filename" - '{}'
      continue
    fi
    target="$target_dir/$old_filename"
    physical_state=verified
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      physical_state=missing
    elif [[ ! -f "$target" || -L "$target" || -z "$expected" ]]; then
      physical_state=modified
    else
      actual="$(elo_file_sha512 "$target")" || { rm -f -- "$error_file"; return; }
      [[ "$actual" == "$expected" ]] || physical_state=modified
    fi

    if ! elo_provider_is_available "$provider"; then
      elo_migration_plan_add "$([[ "$physical_state" == modified ]] && printf modified || printf unmanaged)" \
        "$key" "$name" "$current_version" - "$type" "$old_filename" - '{}'
      continue
    fi

    platform=""
    [[ "$type" != shader ]] || platform="$(elo_migration_shader_platform \
      "$provider" "$project_id" "$current_version_id" "$loader")"
    : >"$error_file"
    if ! target_metadata="$(elo_provider_call "$provider" resolve "$project_id" \
      "$target_version" "$loader" "" "$platform" 2>"$error_file")"; then
      if [[ -s "$error_file" ]] && ! grep -F "No compatible" "$error_file" >/dev/null 2>&1; then
        cat -- "$error_file" >&2
        rm -f -- "$error_file"
        return 1
      fi
      elo_migration_plan_add "$([[ "$physical_state" == modified ]] && printf modified || printf unavailable)" \
        "$key" "$name" "$current_version" - "$type" "$old_filename" - '{}'
      continue
    fi

    target_version_id="$(printf '%s' "$target_metadata" | jq -r '.version_id')"
    target_version_number="$(printf '%s' "$target_metadata" | jq -r '.version_number')"
    new_filename="$(printf '%s' "$target_metadata" | jq -r '.filename')"
    target_type="$(printf '%s' "$target_metadata" | jq -r '.type')"
    target_hash="$(printf '%s' "$target_metadata" | jq -r '.sha512 // ""')"
    if [[ "$physical_state" == modified ]]; then
      elo_migration_plan_add modified "$key" "$name" "$current_version" \
        "$target_version_number" "$type" "$old_filename" "$new_filename" "$target_metadata"
    elif [[ "$target_type" != "$type" ]]; then
      elo_migration_plan_add unavailable "$key" "$name" "$current_version" - \
        "$type" "$old_filename" - '{}'
    elif [[ "$physical_state" == missing ]]; then
      elo_migration_plan_add restore "$key" "$name" "$current_version" \
        "$target_version_number" "$type" "$old_filename" "$new_filename" "$target_metadata"
    elif [[ "$new_filename" != "$old_filename" && -e "$(elo_addon_type_dir "$instance" "$type")/$new_filename" ]]; then
      elo_migration_plan_add collision "$key" "$name" "$current_version" \
        "$target_version_number" "$type" "$old_filename" "$new_filename" "$target_metadata"
    elif [[ -z "$target_hash" ]]; then
      elo_migration_plan_add unavailable "$key" "$name" "$current_version" - \
        "$type" "$old_filename" - '{}'
    elif [[ "$target_version_id" == "$current_version_id" ]]; then
      elo_migration_plan_add keep "$key" "$name" "$current_version" \
        "$target_version_number" "$type" "$old_filename" "$new_filename" "$target_metadata"
    else
      elo_migration_plan_add update "$key" "$name" "$current_version" \
        "$target_version_number" "$type" "$old_filename" "$new_filename" "$target_metadata"
    fi
  done < <(elo_addon_ids "$instance")
  while IFS=$'\t' read -r inventory_state inventory_type inventory_file; do
    [[ "$inventory_state" == external ]] || continue
    elo_migration_plan_add external "external:$inventory_type:$inventory_file" \
      "$inventory_file" - - "$inventory_type" "$inventory_file" - '{}'
  done < <(elo_addons_list_inventory "$instance")
  rm -f -- "$error_file"
}

elo_migration_plan_state() {
  local plan="$1" wanted="$2"
  awk -F '\t' -v wanted="$wanted" '$2 == wanted { print $1; exit }' "$plan"
}

elo_migration_plan_key_by_version() {
  local plan="$1" wanted="$2" state key name current target type old_filename new_filename metadata
  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    [[ "$metadata" != '{}' ]] || continue
    [[ "$(printf '%s' "$metadata" | jq -r '.version_id // ""')" == "$wanted" ]] || continue
    printf '%s\n' "$key"
    return 0
  done <"$plan"
  return 1
}

elo_migration_plan_finalize() {
  local plan="$1" current next changed=1 state key name current_version target type old_filename new_filename metadata
  local provider dep_project dep_version dep_key dep_state blocked
  current="$(mktemp "${TMPDIR:-/tmp}/elo-migration-finalize.XXXXXX")" || return
  next="$current.next"
  cp -- "$plan" "$current"
  while ((changed == 1)); do
    changed=0
    : >"$next"
    while IFS=$'\t' read -r state key name current_version target type old_filename new_filename metadata; do
      blocked=0
      if [[ "$state" == update || "$state" == restore || "$state" == keep ]]; then
        provider="${key%%:*}"
        while IFS=$'\t' read -r dep_project dep_version; do
          [[ "$dep_project" == "-" ]] && dep_project=""
          [[ "$dep_version" == "-" ]] && dep_version=""
          [[ -n "$dep_project" || -n "$dep_version" ]] || continue
          if [[ -n "$dep_project" ]]; then
            dep_key="$provider:$dep_project"
          else
            dep_key="$(elo_migration_plan_key_by_version "$current" "$dep_version" || true)"
          fi
          [[ -n "$dep_key" ]] || { blocked=1; break; }
          dep_state="$(elo_migration_plan_state "$current" "$dep_key")"
          case "$dep_state" in
            keep | update | restore) ;;
            *) blocked=1; break ;;
          esac
        done < <(printf '%s' "$metadata" | jq -r \
          '.dependencies[]? | select(.dependency_type == "required") | [(.project_id // "-"), (.version_id // "-")] | @tsv')
      fi
      if ((blocked == 1)) && [[ "$state" != blocked ]]; then
        state=blocked
        changed=1
      fi
      elo_migration_plan_add "$state" "$key" "$name" "$current_version" "$target" \
        "$type" "$old_filename" "$new_filename" "$metadata" >>"$next"
    done <"$current"
    mv -- "$next" "$current"
  done
  cat -- "$current"
  rm -f -- "$current"
}

elo_migration_plan_create() {
  local instance="$1" target_version="$2" raw
  raw="$(mktemp "${TMPDIR:-/tmp}/elo-migration-raw.XXXXXX")" || return
  elo_migration_plan_build "$instance" "$target_version" >"$raw" || { rm -f -- "$raw"; return 1; }
  elo_migration_plan_finalize "$raw"
  local status=$?
  rm -f -- "$raw"
  return "$status"
}

elo_migration_plan_print() {
  local plan="$1" state key name current target type old_filename new_filename metadata
  printf 'Addon migration analysis:\n\n'
  printf '%-12s %-24s %-28s %-20s %-20s %s\n' STATE SOURCE NAME CURRENT TARGET TYPE
  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    [[ -n "$state" ]] || continue
    printf '%-12s %-24s %-28s %-20s %-20s %s\n' \
      "$state" "$key" "$name" "$current" "$target" "$type"
  done <"$plan"
}

elo_migration_key_selected() {
  local key="$1" selected="$2"
  [[ ",$selected," == *",$key,"* ]]
}

elo_migration_registry_update() {
  local instance="$1" key="$2" metadata="$3" file
  file="$(elo_addon_registry "$instance")"
  elo_kv_set "$file" "${key}_slug" "$(printf '%s' "$metadata" | jq -r '.slug')"
  elo_kv_set "$file" "${key}_name" "$(printf '%s' "$metadata" | jq -r '.name')"
  elo_kv_set "$file" "${key}_version_id" "$(printf '%s' "$metadata" | jq -r '.version_id')"
  elo_kv_set "$file" "${key}_version_number" "$(printf '%s' "$metadata" | jq -r '.version_number')"
  elo_kv_set "$file" "${key}_filename" "$(printf '%s' "$metadata" | jq -r '.filename')"
  elo_kv_set "$file" "${key}_sha512" "$(printf '%s' "$metadata" | jq -r '.sha512')"
  elo_kv_set "$file" "${key}_type" "$(printf '%s' "$metadata" | jq -r '.type')"
  elo_addon_cache_invalidate "$instance" "$key" || true
}

elo_migration_dependencies_update() {
  local instance="$1" plan="$2" file state key name current target type old_filename new_filename metadata
  local provider dep_project dep_version dep_key dependencies
  file="$(elo_addon_registry "$instance")"
  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    [[ "$state" == update || "$state" == restore ]] || continue
    provider="${key%%:*}"
    dependencies=""
    while IFS=$'\t' read -r dep_project dep_version; do
      [[ "$dep_project" == "-" ]] && dep_project=""
      [[ "$dep_version" == "-" ]] && dep_version=""
      if [[ -n "$dep_project" ]]; then
        dep_key="$provider:$dep_project"
      else
        dep_key="$(elo_migration_plan_key_by_version "$plan" "$dep_version" || true)"
      fi
      [[ -n "$dep_key" ]] || continue
      dependencies="${dependencies}${dependencies:+,}$dep_key"
    done < <(printf '%s' "$metadata" | jq -r \
      '.dependencies[]? | select(.dependency_type == "required") | [(.project_id // "-"), (.version_id // "-")] | @tsv')
    elo_kv_set "$file" "${key}_dependencies" "$dependencies"
  done <"$plan"
}

elo_migration_apply() {
  local instance="$1" target_version="$2" plan="$3" remove_keys="${4:-}"
  local directory stage backup timestamp state key name current target type old_filename new_filename metadata
  local provider version_id staged_filename expected actual source destination old_path
  directory="$(elo_instance_dir "$instance")"
  stage="$(mktemp -d "$directory/.elo-migration-stage.XXXXXX")" || return

  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    [[ "$state" == update || "$state" == restore ]] || continue
    mkdir -p -- "$stage/$type"
    [[ ! -e "$stage/$type/$new_filename" ]] || {
      elo_die "Migration filename collision: $new_filename"
      rm -rf -- "$stage"
      return 1
    }
    provider="${key%%:*}"
    version_id="$(printf '%s' "$metadata" | jq -r '.version_id')"
    staged_filename="$(elo_provider_call "$provider" download "$version_id" "$stage/$type")" || {
      rm -rf -- "$stage"
      return 1
    }
    [[ "$staged_filename" == "$new_filename" && -f "$stage/$type/$new_filename" ]] || {
      elo_die "Provider returned an unexpected migration file: $staged_filename"
      rm -rf -- "$stage"
      return 1
    }
    expected="$(printf '%s' "$metadata" | jq -r '.sha512')"
    actual="$(elo_file_sha512 "$stage/$type/$new_filename")" || { rm -rf -- "$stage"; return; }
    [[ -n "$expected" && "$actual" == "$expected" ]] || {
      elo_die "Migrated addon failed SHA-512 verification: $new_filename"
      rm -rf -- "$stage"
      return 1
    }
  done <"$plan"

  timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
  mkdir -p -- "$directory/.elo-migrations"
  backup="$(mktemp -d "$directory/.elo-migrations/${timestamp}.XXXXXX")" || {
    rm -rf -- "$stage"
    return 1
  }
  mkdir -p -- "$backup/files"
  printf '%s\n' "$target_version" >"$backup/target-version"
  cp -- "$directory/instance.conf" "$backup/instance.conf"
  [[ ! -f "$directory/addons.conf" ]] || cp -- "$directory/addons.conf" "$backup/addons.conf"

  while IFS=$'\t' read -r state key name current target type old_filename new_filename metadata; do
    old_path="$(elo_addon_type_dir "$instance" "$type")/$old_filename"
    if [[ "$state" == update || "$state" == restore ]]; then
      destination="$(elo_addon_type_dir "$instance" "$type")/$new_filename"
      if [[ -e "$old_path" || -L "$old_path" ]]; then
        mkdir -p -- "$backup/files/$type"
        mv -- "$old_path" "$backup/files/$type/$old_filename"
      fi
      mv -- "$stage/$type/$new_filename" "$destination"
      elo_migration_registry_update "$instance" "$key" "$metadata" || return
      elo_info "Migrated: $name ($current -> $target)"
    elif elo_migration_key_selected "$key" "$remove_keys"; then
      if [[ -e "$old_path" || -L "$old_path" ]]; then
        expected="$(elo_kv_get "$(elo_addon_registry "$instance")" "${key}_sha512" || true)"
        [[ -f "$old_path" && ! -L "$old_path" && -n "$expected" ]] || {
          elo_warn "Kept unsafe addon: $name"
          continue
        }
        actual="$(elo_file_sha512 "$old_path")" || return
        [[ "$actual" == "$expected" ]] || { elo_warn "Kept modified addon: $name"; continue; }
        mkdir -p -- "$backup/files/$type"
        mv -- "$old_path" "$backup/files/$type/$old_filename"
      fi
      elo_addon_registry_remove "$instance" "$key"
      elo_info "Removed incompatible addon: $name"
    fi
  done <"$plan"

  elo_migration_dependencies_update "$instance" "$plan" || return
  elo_kv_set "$directory/instance.conf" MINECRAFT_VERSION "$target_version"
  rm -rf -- "$stage"
  elo_info "Instance version changed to $target_version. Migration backup: $backup"
}

elo_cmd_instance_version() {
  local instance="${1:-}" target_version="${2:-}" migrate=0 remove_incompatible=0 dry_run=0
  local current_version relation plan remove_keys="" state key name rest
  elo_require_initialized || return
  if [[ -z "$instance" || -z "$target_version" || "$instance" == --* || "$target_version" == --* ]]; then
    elo_die "Usage: elo instances version <name> <version> [--migrate] [--remove-incompatible] [--dry-run] [--yes]"
    return
  fi
  elo_require_instance "$instance" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --migrate) migrate=1; shift ;;
      --remove-incompatible) remove_incompatible=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for instance version: $1"; return ;;
    esac
  done
  ((remove_incompatible == 0 || migrate == 1)) || {
    elo_die "--remove-incompatible requires --migrate."
    return 1
  }
  current_version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  relation="$(elo_version_relation "$current_version" "$target_version")"
  [[ "$relation" != same ]] || { elo_info "Instance already uses Minecraft $target_version."; return 0; }
  elo_warn "Minecraft version $relation: $current_version -> $target_version. Existing addons may be incompatible and can break startup or worlds."
  plan="$(mktemp "${TMPDIR:-/tmp}/elo-migration-plan.XXXXXX")" || return
  elo_migration_plan_create "$instance" "$target_version" >"$plan" || { rm -f -- "$plan"; return 1; }
  elo_migration_plan_print "$plan"
  ((dry_run == 0)) || { rm -f -- "$plan"; return 0; }
  if ((migrate == 0)); then
    elo_confirm "Change '$instance' to Minecraft $target_version without migrating addons?" || {
      rm -f -- "$plan"; elo_warn "Version change cancelled."; return 1;
    }
    elo_kv_set "$(elo_instance_dir "$instance")/instance.conf" MINECRAFT_VERSION "$target_version"
    rm -f -- "$plan"
    elo_warn "Version changed; addon files were kept unchanged."
    return 0
  fi
  if ((remove_incompatible == 1)); then
    while IFS=$'\t' read -r state key name rest; do
      [[ "$state" == unavailable || "$state" == unmanaged || "$state" == blocked ]] || continue
      remove_keys="${remove_keys}${remove_keys:+,}$key"
    done <"$plan"
  fi
  elo_confirm "Migrate compatible addons and change '$instance' to Minecraft $target_version?" || {
    rm -f -- "$plan"; elo_warn "Migration cancelled."; return 1;
  }
  elo_migration_apply "$instance" "$target_version" "$plan" "$remove_keys"
  local status=$?
  rm -f -- "$plan"
  return "$status"
}

elo_addon_registry_inventory() {
  local instance="$1" file
  file="$(elo_addon_registry "$instance")"
  [[ -f "$file" ]] || return 0
  awk '
    function value(line, position, result) {
      position = index(line, "=")
      result = substr(line, position + 1)
      if (result ~ /^".*"$/) result = substr(result, 2, length(result) - 2)
      return result
    }
    {
      position = index($0, "=")
      if (position == 0) next
      key = substr($0, 1, position - 1)
      values[key] = value($0)
      if (key == "addon_ids") count = split(values[key], ids, ",")
    }
    END {
      for (i = 1; i <= count; i++) {
        id = ids[i]
        if (id == "") continue
        printf "registered\t%s\t%s\t%s\t%s\t%s\t%s\n", id,
          values[id "_type"], values[id "_filename"], values[id "_sha512"],
          values[id "_name"], values[id "_version_number"]
      }
    }
  ' "$file"
}

elo_addons_list_inventory() {
  local instance="$1" directory entry entry_type filename
  elo_require_initialized || return
  elo_require_instance "$instance" || return
  {
    elo_addon_registry_inventory "$instance"
    for entry_type in mod resourcepack shader; do
      directory="$(elo_addon_type_dir "$instance" "$entry_type")"
      shopt -s nullglob dotglob
      for entry in "$directory"/*; do
        [[ -f "$entry" && ! -L "$entry" ]] || continue
        filename="${entry##*/}"
        printf 'physical\t-\t%s\t%s\t-\t-\t-\n' "$entry_type" "$filename"
      done
      shopt -u nullglob dotglob
    done
  } | awk -F '\t' '
    $1 == "registered" {
      known[$3 SUBSEP $4] = 1
      print
      next
    }
    $1 == "physical" && !known[$3 SUBSEP $4] {
      printf "external\t-\t%s\t%s\t-\t%s\t-\n", $3, $4, $4
    }
  '
}

elo_addons_list_inventory_row() {
  local instance="$1" kind="$2" key="$3" type="$4" filename="$5"
  local expected="$6" name="$7" version="$8" target state
  if [[ "$kind" == "external" ]]; then
    elo_addon_table_row - "$name" "$type" - external "$filename"
    return
  fi
  if [[ -z "$filename" || "$filename" == */* || "$filename" == *$'\n'* ]]; then
    state=missing
  else
    target="$(elo_addon_type_dir "$instance" "$type")/$filename" || return
    state="$(elo_addon_cached_state "$instance" "$key" "$expected" "$target")" || return
  fi
  elo_addon_table_row "$key" "$name" "$type" "$version" "$state" "$filename"
}

elo_addons_list_inventory_page() {
  local instance="$1" inventory="$2" offset="$3" limit="$4"
  local index=0 kind key type filename expected name version
  elo_addon_table_row SOURCE NAME TYPE VERSION STATE FILE
  printf '%s\n' '----------------------------------------------------------------------------------------------------------------------------------------------------------------'
  while IFS=$'\t' read -r kind key type filename expected name version || [[ -n "$kind" ]]; do
    if ((index >= offset && index < offset + limit)); then
      elo_addons_list_inventory_row \
        "$instance" "$kind" "$key" "$type" "$filename" "$expected" "$name" "$version" || return
    fi
    index=$((index + 1))
    if ((index >= offset + limit)); then break; fi
  done <"$inventory"
  return 0
}

elo_cmd_addons_list() {
  local instance="${1:-}" inventory kind key type filename expected name version
  elo_require_initialized || return
  [[ -n "$instance" && "$instance" != --* ]] || { elo_die "Usage: elo addons list <instance>"; return; }
  elo_require_instance "$instance" || return
  (($# == 1)) || { elo_die "Usage: elo addons list <instance>"; return; }
  inventory="$(elo_addons_list_inventory "$instance")" || return
  elo_addon_table_row SOURCE NAME TYPE VERSION STATE FILE
  printf '%s\n' '----------------------------------------------------------------------------------------------------------------------------------------------------------------'
  while IFS=$'\t' read -r kind key type filename expected name version || [[ -n "$kind" ]]; do
    [[ -n "$kind" ]] || continue
    elo_addons_list_inventory_row \
      "$instance" "$kind" "$key" "$type" "$filename" "$expected" "$name" "$version" || return
  done <<<"$inventory"
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
    elo_die "Usage: elo addons adopt <instance> <relative-path> [--yes]"
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

elo_cmd_addon_remove() {
  local instance="${1:-}" addon="" provider="" key="" file type filename target relative="" expected actual remove_orphans=0
  elo_require_initialized || return
  if [[ -z "$instance" || "$instance" == --* ]]; then elo_die "Usage: elo addons remove <instance> <id-or-slug> [options]"; return; fi
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
