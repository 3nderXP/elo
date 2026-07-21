#!/usr/bin/env bash

elo_mrpack_require_tools() {
  command -v curl >/dev/null 2>&1 || { elo_die "curl is required for Modrinth modpack imports."; return; }
  command -v jq >/dev/null 2>&1 || { elo_die "jq is required for Modrinth modpack imports."; return; }
  command -v unzip >/dev/null 2>&1 || { elo_die "unzip is required for Modrinth modpack imports."; return; }
  command -v sha512sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
    elo_die "sha512sum or shasum is required for Modrinth modpack imports."
    return 1
  }
}

elo_mrpack_progress() {
  local current="$1" total="$2" label="$3" width=42 filled empty percent bar i
  ((total > 0)) || { elo_info "Modpack progress: no downloadable files"; return 0; }
  percent=$((current * 100 / total))
  if [[ -t 1 ]]; then
    filled=$((current * width / total))
    empty=$((width - filled))
    bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}▒"; done
    printf '\r\033[2KModpack [%s] %3d%% (%d/%d) %s' "$bar" "$percent" "$current" "$total" "$label"
    [[ "$current" == "$total" ]] && printf '\n'
  else
    elo_info "Modpack progress: $current/$total ($percent%): $label"
  fi
}

elo_mrpack_safe_path() {
  local path="$1" part
  [[ -n "$path" && "$path" != /* && "$path" != */ && "$path" != *//* && \
    "$path" != \\* && "$path" != *\\* && "$path" != *['*?[]'* && \
    "$path" != *$'\n'* && "$path" != *$'\r'* && "$path" != *$'\t'* && \
    ! "$path" =~ ^[a-zA-Z]: ]] || return 1
  while IFS= read -r part || [[ -n "$part" ]]; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
  done < <(printf '%s' "$path" | tr '/' '\n')
}

elo_mrpack_url_allowed() {
  [[ "$1" != *[[:space:]]* && "$1" != *\\* ]] || return 1
  case "$1" in
    https://cdn.modrinth.com/* | https://github.com/* | \
      https://raw.githubusercontent.com/* | https://gitlab.com/*) return 0 ;;
    *) return 1 ;;
  esac
}

elo_mrpack_loader() {
  local index="$1" loaders loader
  loaders="$(printf '%s' "$index" | jq -r '
    .dependencies | to_entries[] |
    select(.key == "fabric-loader" or .key == "quilt-loader" or
      .key == "forge" or .key == "neoforge") | .key')"
  if [[ "$(printf '%s\n' "$loaders" | sed '/^$/d' | wc -l | tr -d ' ')" -gt 1 ]]; then
    elo_die "Modpack declares more than one mod loader."
    return 1
  fi
  loader="$(printf '%s\n' "$loaders" | sed -n '1p')"
  case "$loader" in
    fabric-loader) printf 'fabric\n' ;;
    quilt-loader) printf 'quilt\n' ;;
    forge | neoforge) printf '%s\n' "$loader" ;;
    "") printf 'vanilla\n' ;;
  esac
}

elo_mrpack_validate_index() {
  local index="$1" path url root
  if ! printf '%s' "$index" | jq -e '
    .formatVersion == 1 and .game == "minecraft" and
    (.name | type == "string" and length > 0 and (contains("\n") | not)) and
    (.versionId | type == "string" and length > 0 and (contains("\n") | not)) and
    (.dependencies | type == "object") and
    (.dependencies.minecraft | type == "string" and length > 0 and (contains("\n") | not)) and
    (.files | type == "array") and
    all(.files[];
      (.path | type == "string" and length > 0) and
      (.hashes.sha512 | type == "string" and test("^[0-9a-fA-F]{128}$")) and
      (.downloads | type == "array" and length > 0 and all(.[]; type == "string")) and
      ((.fileSize == null) or (.fileSize | type == "number" and floor == . and . >= 0)) and
      ((.env.client == null) or (.env.client == "required") or
        (.env.client == "optional") or (.env.client == "unsupported")))' \
    >/dev/null 2>&1; then
    elo_die "Invalid or unsupported modrinth.index.json."
    return 1
  fi

  while IFS= read -r path || [[ -n "$path" ]]; do
    elo_mrpack_safe_path "$path" || { elo_die "Unsafe modpack file path: $path"; return 1; }
    root="${path%%/*}"
    case "$root" in
      mods | resourcepacks | shaderpacks | config | saves | data | defaultconfigs | kubejs | scripts | options.txt | servers.dat | icon.png) ;;
      *) elo_die "Unsupported modpack file path outside Elo-managed folders: $path"; return 1 ;;
    esac
  done < <(printf '%s' "$index" | jq -r '.files[].path')
  while IFS= read -r url || [[ -n "$url" ]]; do
    elo_mrpack_url_allowed "$url" || { elo_die "Modpack download URL is not allowed: $url"; return 1; }
  done < <(printf '%s' "$index" | jq -r '.files[].downloads[]')
}

elo_mrpack_validate_archive() {
  local pack="$1" entries entry normalized duplicates index_count
  [[ -f "$pack" && ! -L "$pack" ]] || { elo_die "Modpack must be a regular file: $pack"; return; }
  [[ "$pack" == *.mrpack ]] || { elo_die "Modpack file must use the .mrpack extension."; return; }
  unzip -tqq "$pack" >/dev/null 2>&1 || { elo_die "Invalid or damaged .mrpack archive."; return; }
  entries="$(unzip -Z1 "$pack")" || { elo_die "Could not inspect .mrpack archive."; return; }
  index_count="$(printf '%s\n' "$entries" | awk '$0 == "modrinth.index.json" { count++ } END { print count + 0 }')"
  [[ "$index_count" == "1" ]] || { elo_die "Archive must contain one root modrinth.index.json."; return; }
  duplicates="$(printf '%s\n' "$entries" | LC_ALL=C sort | uniq -d)"
  [[ -z "$duplicates" ]] || { elo_die "Archive contains duplicate entries."; return; }
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" ]] || continue
    normalized="${entry%/}"
    [[ -n "$normalized" ]] || { elo_die "Archive contains an unsafe path."; return 1; }
    elo_mrpack_safe_path "$normalized" || { elo_die "Unsafe archive path: $entry"; return 1; }
  done <<<"$entries"
}

elo_mrpack_registry_add() {
  local stage_name="$1" path="$2" hash="$3" url="$4" pack_version="$5"
  local root filename type provider project_id version_id local_id metadata key slug
  root="${path%%/*}"
  filename="${path#*/}"
  [[ "$filename" != */* ]] || return 0
  case "$root" in
    mods) type=mod ;;
    resourcepacks) type=resourcepack ;;
    shaderpacks) type=shader ;;
    *) return 0 ;;
  esac
  provider=local
  local_id="$(elo_text_sha512 "$path")" || return
  project_id="$local_id"
  slug="$filename"
  version_id="$pack_version"
  if [[ "$url" =~ ^https://cdn\.modrinth\.com/data/([^/]+)/versions/([^/]+)/ ]]; then
    provider=modrinth
    project_id="${BASH_REMATCH[1]}"
    version_id="${BASH_REMATCH[2]}"
    slug="$project_id"
  fi
  key="$(elo_addon_key "$provider" "$project_id")"
  if elo_addon_is_registered "$stage_name" "$key"; then
    provider=local
    project_id="$local_id"
    slug="$filename"
    version_id="$pack_version"
    key="$(elo_addon_key "$provider" "$project_id")"
  fi
  metadata="$(jq -cn --arg id "$project_id" --arg slug "$slug" \
    --arg name "$filename" --arg version_id "$version_id" \
    --arg version_number "$pack_version" --arg filename "$filename" \
    --arg hash "$hash" --arg type "$type" \
    '{project_id:$id,slug:$slug,name:$name,version_id:$version_id,
      version_number:$version_number,filename:$filename,sha512:$hash,type:$type}')" || return
  elo_addon_registry_add "$stage_name" "$provider" "$metadata" false
}

elo_mrpack_download_file() {
  local stage="$1" stage_name="$2" entry="$3" pack_version="$4"
  local path hash size target directory temporary urls url downloaded_url="" actual_size actual_hash downloaded=0
  path="$(printf '%s' "$entry" | jq -r '.path')"
  hash="$(printf '%s' "$entry" | jq -r '.hashes.sha512 | ascii_downcase')"
  size="$(printf '%s' "$entry" | jq -r '.fileSize // empty')"
  urls="$(printf '%s' "$entry" | jq -r '.downloads[]')"
  target="$stage/$path"
  directory="${target%/*}"
  [[ ! -e "$target" && ! -L "$target" ]] || { elo_die "Modpack file collision: $path"; return; }
  mkdir -p -- "$directory"
  temporary="$(mktemp "$directory/.elo-mrpack-download.XXXXXX")" || return
  while IFS= read -r url || [[ -n "$url" ]]; do
    curl -fsSL -A "$ELO_MODRINTH_USER_AGENT" --max-redirs 5 "$url" -o "$temporary" || continue
    if [[ -n "$size" ]]; then
      actual_size="$(wc -c <"$temporary" | tr -d ' ')"
      [[ "$actual_size" == "$size" ]] || continue
    fi
    actual_hash="$(elo_file_sha512 "$temporary")" || { rm -f -- "$temporary"; return 1; }
    [[ "$actual_hash" == "$hash" ]] || continue
    downloaded=1
    downloaded_url="$url"
    break
  done <<<"$urls"
  if ((downloaded == 0)); then
    rm -f -- "$temporary"
    elo_die "Modpack file download or integrity check failed: $path"
    return 1
  fi
  mv -- "$temporary" "$target"
  elo_mrpack_registry_add "$stage_name" "$path" "$hash" "$downloaded_url" "$pack_version"
}

elo_mrpack_apply_overrides() {
  local pack="$1" index="$2" stage="$3" prefix="$4" entry relative root target directory temporary
  local skipped_count=0 skipped_names=""
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    case "$entry" in "$prefix"/*) ;; *) continue ;; esac
    [[ "$entry" != */ ]] || continue
    relative="${entry#"$prefix"/}"
    elo_mrpack_safe_path "$relative" || { elo_die "Unsafe override path: $entry"; return 1; }
    root="${relative%%/*}"
    case "$root" in
      mods | resourcepacks | shaderpacks | config | saves) ;;
      *)
        skipped_count=$((skipped_count + 1))
        skipped_names="${skipped_names}${skipped_names:+, }$relative"
        continue
        ;;
    esac
    if printf '%s' "$index" | jq -e --arg path "$relative" \
      'any(.files[]; .path == $path and (.env.client // "required") != "unsupported")' >/dev/null; then
      elo_die "Override collides with an indexed modpack file: $relative"
      return 1
    fi
    target="$stage/$relative"
    directory="${target%/*}"
    mkdir -p -- "$directory"
    temporary="$(mktemp "$directory/.elo-mrpack-override.XXXXXX")" || return
    if ! unzip -p "$pack" "$entry" >"$temporary"; then
      rm -f -- "$temporary"
      elo_die "Could not extract modpack override: $entry"
      return 1
    fi
    mv -f -- "$temporary" "$target"
  done < <(unzip -Z1 "$pack")
  if ((skipped_count > 0)); then
    elo_info "Ignored $skipped_count $prefix file(s) outside Elo-managed folders: $skipped_names"
  fi
}

elo_mrpack_install_stage() {
  local name="$1" pack="$2" index="$3" version="$4" loader="$5" stage="$6"
  local source="${7:-local}" source_version="${8:-}" stage_name
  local entry current=0 total path
  stage_name="${stage##*/}"
  mkdir -p -- "$stage"/{mods,resourcepacks,shaderpacks,config,saves}
  : >"$stage/instance.conf"
  elo_kv_set "$stage/instance.conf" INSTANCE_NAME "$name"
  elo_kv_set "$stage/instance.conf" MINECRAFT_VERSION "$version"
  elo_kv_set "$stage/instance.conf" LOADER "$loader"
  elo_kv_set "$stage/instance.conf" CREATED_AT "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  elo_kv_set "$stage/instance.conf" NOTES "Imported from $(basename -- "$pack")"
  elo_kv_set "$stage/instance.conf" MODPACK_NAME "$(printf '%s' "$index" | jq -r '.name')"
  elo_kv_set "$stage/instance.conf" MODPACK_VERSION "$(printf '%s' "$index" | jq -r '.versionId')"
  elo_kv_set "$stage/instance.conf" MODPACK_SOURCE "$source"
  elo_kv_set "$stage/instance.conf" MODPACK_SOURCE_VERSION "$source_version"

  total="$(printf '%s' "$index" | jq '[.files[] | select((.env.client // "required") != "unsupported")] | length')"
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" ]] || continue
    current=$((current + 1))
    path="$(printf '%s' "$entry" | jq -r '.path')"
    elo_mrpack_progress "$current" "$total" "$path"
    elo_mrpack_download_file "$stage" "$stage_name" "$entry" \
      "$(printf '%s' "$index" | jq -r '.versionId')" || return
  done < <(printf '%s' "$index" | jq -c '.files[] | select((.env.client // "required") != "unsupported")')
  elo_info "Applying modpack overrides..."
  elo_mrpack_apply_overrides "$pack" "$index" "$stage" overrides || return
  elo_mrpack_apply_overrides "$pack" "$index" "$stage" client-overrides || return
  if unzip -Z1 "$pack" | awk '/^server-overrides\// { found=1 } END { exit !found }'; then
    elo_info "Ignored server-overrides for client instance import."
  fi
  local managed_paths="" relative root
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    relative="${entry#"$stage"/}"; root="${relative%%/*}"
    case "$root" in mods|resourcepacks|shaderpacks|config|saves|instance.conf|addons.conf) continue ;; esac
    managed_paths="${managed_paths}${managed_paths:+,}$relative"
  done < <(find "$stage" -type f)
  [[ -z "$managed_paths" ]] || elo_kv_set "$stage/instance.conf" MANAGED_PATHS "$managed_paths"
}

elo_mrpack_instance_is_empty() {
  local instance="$1" directory folder entry
  local -a entries
  directory="$(elo_instance_dir "$instance")"
  for folder in mods resourcepacks shaderpacks config saves; do
    shopt -s nullglob dotglob
    entries=("$directory/$folder"/*)
    shopt -u nullglob dotglob
    for entry in "${entries[@]}"; do
      [[ -e "$entry" || -L "$entry" ]] && return 1
    done
  done
  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ -n "$path" ]] || continue
    [[ -e "$directory/$path" || -L "$directory/$path" ]] && return 1
  done < <(elo_instance_managed_paths "$instance")
  [[ -z "$(elo_addon_ids "$instance")" ]]
}

elo_mrpack_warn_instance_contents() {
  local instance="$1"
  elo_mrpack_instance_is_empty "$instance" && return 0
  elo_warn "Instance '$instance' is not empty. Installing a modpack may conflict with existing addons; using an empty instance is recommended."
}

elo_mrpack_require_instance_compatibility() {
  local instance="$1" version="$2" loader="$3" current_version current_loader
  current_version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  current_loader="$(elo_instance_metadata "$instance" LOADER)"
  if [[ "$current_version" != "unknown" && "$current_version" != "$version" ]]; then
    elo_die "Modpack requires Minecraft $version, but instance '$instance' uses $current_version."
    return 1
  fi
  if [[ "$current_loader" != "unknown" && "$current_loader" != "$loader" ]]; then
    elo_die "Modpack requires loader '$loader', but instance '$instance' uses '$current_loader'."
    return 1
  fi
}

elo_mrpack_preflight_instance() {
  local instance="$1" pack="$2" index="$3" directory path entry prefix relative root target
  directory="$(elo_instance_dir "$instance")"
  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ -n "$path" ]] || continue
    target="$directory/$path"
    if [[ -e "$target" || -L "$target" ]]; then
      elo_die "Modpack file conflicts with existing instance data: $path"
      return 1
    fi
  done < <(printf '%s' "$index" | jq -r '.files[] | select((.env.client // "required") != "unsupported") | .path')
  for prefix in overrides client-overrides; do
    while IFS= read -r entry || [[ -n "$entry" ]]; do
      case "$entry" in "$prefix"/*) ;; *) continue ;; esac
      [[ "$entry" != */ ]] || continue
      relative="${entry#"$prefix"/}"
      root="${relative%%/*}"
      case "$root" in mods | resourcepacks | shaderpacks | config | saves | data | defaultconfigs | kubejs | scripts | options.txt | servers.dat | icon.png) ;; *) continue ;; esac
      target="$directory/$relative"
      if [[ -e "$target" || -L "$target" ]]; then
        elo_die "Modpack override conflicts with existing instance data: $relative"
        return 1
      fi
    done < <(unzip -Z1 "$pack")
  done
}

elo_mrpack_stage_metadata() {
  local stage_name="$1" key="$2" file metadata
  file="$(elo_addon_registry "$stage_name")"
  metadata="$(jq -cn \
    --arg project_id "${key#*:}" \
    --arg slug "$(elo_kv_get "$file" "${key}_slug")" \
    --arg name "$(elo_kv_get "$file" "${key}_name")" \
    --arg version_id "$(elo_kv_get "$file" "${key}_version_id")" \
    --arg version_number "$(elo_kv_get "$file" "${key}_version_number")" \
    --arg filename "$(elo_kv_get "$file" "${key}_filename")" \
    --arg sha512 "$(elo_kv_get "$file" "${key}_sha512")" \
    --arg type "$(elo_kv_get "$file" "${key}_type")" \
    --arg dependency_keys "$(elo_kv_get "$file" "${key}_dependencies" || true)" \
    '{project_id:$project_id,slug:$slug,name:$name,version_id:$version_id,
      version_number:$version_number,filename:$filename,sha512:$sha512,
      type:$type,dependency_keys:$dependency_keys}')" || return
  printf '%s\n' "$metadata"
}

elo_mrpack_merge_stage() {
  local instance="$1" stage="$2" stage_name source relative target key provider metadata folder
  stage_name="${stage##*/}"
  while IFS= read -r key || [[ -n "$key" ]]; do
    [[ -n "$key" ]] || continue
    if elo_addon_is_registered "$instance" "$key"; then
      elo_die "Modpack addon is already registered in instance: $key"
      return 1
    fi
  done < <(elo_addon_ids "$stage_name")
  while IFS= read -r source || [[ -n "$source" ]]; do
      [[ -n "$source" ]] || continue
      [[ "$source" == "$stage/instance.conf" || "$source" == "$stage/addons.conf" ]] && continue
      relative="${source#"$stage"/}"
      target="$(elo_instance_dir "$instance")/$relative"
      if [[ -e "$target" || -L "$target" ]]; then
        elo_die "Modpack file appeared during installation: $relative"
        return 1
      fi
  done < <(find "$stage" -type f)

  while IFS= read -r source || [[ -n "$source" ]]; do
      [[ -n "$source" ]] || continue
      [[ "$source" == "$stage/instance.conf" || "$source" == "$stage/addons.conf" ]] && continue
      relative="${source#"$stage"/}"
      target="$(elo_instance_dir "$instance")/$relative"
      mkdir -p -- "${target%/*}"
      mv -- "$source" "$target" || return
  done < <(find "$stage" -type f)
  while IFS= read -r key || [[ -n "$key" ]]; do
    [[ -n "$key" ]] || continue
    provider="${key%%:*}"
    metadata="$(elo_mrpack_stage_metadata "$stage_name" "$key")" || return
    elo_addon_registry_add "$instance" "$provider" "$metadata" false || return
  done < <(elo_addon_ids "$stage_name")
}

elo_mrpack_install_into_instance() {
  local instance="$1" pack="$2" dry_run="$3" source="${4:-local}" source_version="${5:-}"
  local index version loader file_count optional_count stage empty=0 config
  elo_mrpack_require_tools || return
  elo_mrpack_validate_archive "$pack" || return
  index="$(unzip -p "$pack" modrinth.index.json)" || { elo_die "Could not read modrinth.index.json."; return; }
  elo_mrpack_validate_index "$index" || return
  version="$(printf '%s' "$index" | jq -r '.dependencies.minecraft')"
  loader="$(elo_mrpack_loader "$index")" || return
  elo_mrpack_instance_is_empty "$instance" && empty=1
  elo_mrpack_warn_instance_contents "$instance"
  ((empty == 1)) || elo_mrpack_require_instance_compatibility "$instance" "$version" "$loader" || return
  elo_mrpack_preflight_instance "$instance" "$pack" "$index" || return
  file_count="$(printf '%s' "$index" | jq '[.files[] | select((.env.client // "required") != "unsupported")] | length')"
  optional_count="$(printf '%s' "$index" | jq '[.files[] | select(.env.client == "optional")] | length')"
  printf 'Modpack installation plan:\n'
  printf '  Pack: %s (%s)\n' "$(printf '%s' "$index" | jq -r '.name')" "$(printf '%s' "$index" | jq -r '.versionId')"
  printf '  Instance: %s\n  Minecraft: %s\n  Loader: %s\n  Files to download: %s\n' \
    "$instance" "$version" "$loader" "$file_count"
  ((optional_count == 0)) || printf '  Optional client files included: %s\n' "$optional_count"
  ((dry_run == 0)) || return 0
  elo_confirm "Install this Modrinth modpack into instance '$instance'?" || { elo_warn "Modpack installation cancelled."; return 1; }

  elo_info "Starting modpack download and extraction..."
  stage="$(mktemp -d "$ELO_INSTANCES_DIR/.elo-mrpack-content.XXXXXX")" || return
  if ! elo_mrpack_install_stage "$instance" "$pack" "$index" "$version" "$loader" "$stage"; then
    [[ -t 1 ]] && printf '\n'
    rm -rf -- "$stage"
    return 1
  fi
  if ! elo_mrpack_merge_stage "$instance" "$stage"; then
    rm -rf -- "$stage"
    return 1
  fi
  config="$(elo_instance_dir "$instance")/instance.conf"
  if ((empty == 1)); then
    elo_kv_set "$config" MINECRAFT_VERSION "$version"
    elo_kv_set "$config" LOADER "$loader"
  fi
  elo_kv_set "$config" MODPACK_NAME "$(printf '%s' "$index" | jq -r '.name')"
  elo_kv_set "$config" MODPACK_VERSION "$(printf '%s' "$index" | jq -r '.versionId')"
  elo_kv_set "$config" MODPACK_SOURCE "$source"
  elo_kv_set "$config" MODPACK_SOURCE_VERSION "$source_version"
  rm -rf -- "$stage"
  elo_info "Modpack installed into instance: $instance"
  [[ "$loader" == "vanilla" ]] || elo_warn "Elo records loader metadata but does not install the loader itself."
}

elo_mrpack_fetch_provider_archive() {
  local provider="$1" addon="$2" version="$3" loader="$4"
  local metadata type temporary filename archive expected actual
  metadata="$(elo_provider_call "$provider" resolve "$addon" "$version" "$loader")" || return
  type="$(printf '%s' "$metadata" | jq -r '.type')"
  [[ "$type" == "modpack" ]] || { elo_die "Provider project is not a modpack: $addon"; return 1; }
  temporary="$(mktemp -d "$ELO_INSTANCES_DIR/.elo-mrpack-source.XXXXXX")" || return
  elo_info "Downloading modpack archive from $provider..." >&2
  filename="$(elo_provider_call "$provider" download "$(printf '%s' "$metadata" | jq -r '.version_id')" "$temporary")" || {
    rm -rf -- "$temporary"
    return 1
  }
  archive="$temporary/$filename"
  expected="$(printf '%s' "$metadata" | jq -r '.sha512 // "" | ascii_downcase')"
  actual="$(elo_file_sha512 "$archive")" || { rm -rf -- "$temporary"; return 1; }
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    rm -rf -- "$temporary"
    elo_die "Downloaded modpack failed SHA-512 verification: $filename"
    return 1
  fi
  printf '%s\n' "$temporary"
  printf '%s\n' "$archive"
  printf '%s\n' "$provider:$(printf '%s' "$metadata" | jq -r '.project_id')"
  printf '%s\n' "$(printf '%s' "$metadata" | jq -r '.version_id')"
}

elo_mrpack_install_from_provider() {
  local instance="$1" provider="$2" addon="$3" dry_run="$4"
  local version loader fetched temporary archive source source_version status=0
  version="$(elo_instance_metadata "$instance" MINECRAFT_VERSION)"
  loader="$(elo_instance_metadata "$instance" LOADER)"
  fetched="$(elo_mrpack_fetch_provider_archive "$provider" "$addon" "$version" "$loader")" || return
  temporary="$(sed -n '1p' <<<"$fetched")"
  archive="$(sed -n '2p' <<<"$fetched")"
  source="$(sed -n '3p' <<<"$fetched")"
  source_version="$(sed -n '4p' <<<"$fetched")"
  elo_mrpack_install_into_instance "$instance" "$archive" "$dry_run" "$source" "$source_version" || status=$?
  rm -rf -- "$temporary"
  return "$status"
}

elo_mrpack_import_archive_as_instance() {
  local name="$1" pack="$2" source="${3:-local}" source_version="${4:-}"
  local index version loader directory stage file_count optional_count
  elo_mrpack_require_tools || return
  directory="$(elo_instance_dir "$name")"
  [[ ! -e "$directory" && ! -L "$directory" ]] || { elo_die "Instance '$name' already exists."; return; }
  elo_mrpack_validate_archive "$pack" || return
  index="$(unzip -p "$pack" modrinth.index.json)" || { elo_die "Could not read modrinth.index.json."; return; }
  elo_mrpack_validate_index "$index" || return
  version="$(printf '%s' "$index" | jq -r '.dependencies.minecraft')"
  loader="$(elo_mrpack_loader "$index")" || return
  file_count="$(printf '%s' "$index" | jq '[.files[] | select((.env.client // "required") != "unsupported")] | length')"
  optional_count="$(printf '%s' "$index" | jq '[.files[] | select(.env.client == "optional")] | length')"
  printf 'Modpack installation plan:\n'
  printf '  Pack: %s (%s)\n' "$(printf '%s' "$index" | jq -r '.name')" "$(printf '%s' "$index" | jq -r '.versionId')"
  printf '  Instance: %s\n  Minecraft: %s\n  Loader: %s\n  Files to download: %s\n' \
    "$name" "$version" "$loader" "$file_count"
  ((optional_count == 0)) || printf '  Optional client files included: %s\n' "$optional_count"
  elo_confirm "Install this Modrinth modpack as instance '$name'?" || { elo_warn "Modpack import cancelled."; return 1; }

  mkdir -p -- "$ELO_INSTANCES_DIR"
  stage="$(mktemp -d "$ELO_INSTANCES_DIR/.elo-mrpack-$name.XXXXXX")" || return
  if ! elo_mrpack_install_stage "$name" "$pack" "$index" "$version" "$loader" "$stage" "$source" "$source_version"; then
    [[ -t 1 ]] && printf '\n'
    rm -rf -- "$stage"
    return 1
  fi
  if [[ -e "$directory" || -L "$directory" ]]; then
    rm -rf -- "$stage"
    elo_die "Instance '$name' appeared during modpack import; staged data was discarded."
    return 1
  fi
  mv -- "$stage" "$directory"
  elo_info "Modpack installed as instance: $name"
  [[ "$loader" == "vanilla" ]] || elo_warn "Elo records loader metadata but does not install the loader itself."
}

elo_mrpack_import_from_provider() {
  local name="$1" provider="$2" addon="$3"
  local fetched temporary archive source source_version status=0
  fetched="$(elo_mrpack_fetch_provider_archive "$provider" "$addon" "" "")" || return
  temporary="$(sed -n '1p' <<<"$fetched")"
  archive="$(sed -n '2p' <<<"$fetched")"
  source="$(sed -n '3p' <<<"$fetched")"
  source_version="$(sed -n '4p' <<<"$fetched")"
  elo_mrpack_import_archive_as_instance "$name" "$archive" "$source" "$source_version" || status=$?
  rm -rf -- "$temporary"
  return "$status"
}

elo_cmd_import_mrpack() {
  local name="${1:-}" pack="${2:-}"
  elo_require_initialized || return
  if [[ -z "$name" || -z "$pack" || "$name" == --* || "$pack" == --* ]]; then
    elo_die "Usage: elo instances import <name> <file.mrpack> [--yes]"
    return
  fi
  elo_validate_instance_name "$name" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for modpack import: $1"; return ;;
    esac
  done
  elo_mrpack_import_archive_as_instance "$name" "$pack" local ""
}

elo_cmd_import() {
  local name="${1:-}" source="${2:-}" provider="" project_type
  elo_require_initialized || return
  if [[ -z "$name" || -z "$source" || "$name" == --* || "$source" == --* ]]; then
    elo_die "Usage: elo instances import <name> <file.mrpack|id-or-slug> [--provider <name>] [--yes]"
    return
  fi
  elo_validate_instance_name "$name" || return
  shift 2
  while (($# > 0)); do
    case "$1" in
      --provider) elo_require_value "$1" "${2:-}" || return; provider="$2"; shift 2 ;;
      --yes) ELO_ASSUME_YES=1; shift ;;
      *) elo_die "Invalid option for modpack import: $1"; return ;;
    esac
  done

  if [[ "$source" == *.mrpack || -f "$source" || -L "$source" ]]; then
    [[ -z "$provider" ]] || { elo_die "--provider cannot be used with a local .mrpack file."; return; }
    elo_mrpack_import_archive_as_instance "$name" "$source" local ""
    return
  fi

  provider="${provider:-$(elo_preferred_provider)}"
  project_type="$(elo_provider_call "$provider" project_type "$source")" || return
  [[ "$project_type" == "modpack" ]] || { elo_die "Provider project is not a modpack: $source"; return; }
  elo_mrpack_import_from_provider "$name" "$provider" "$source"
}
