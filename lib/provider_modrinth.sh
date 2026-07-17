#!/usr/bin/env bash

ELO_MODRINTH_API="${ELO_MODRINTH_API:-https://api.modrinth.com/v2}"
ELO_MODRINTH_USER_AGENT="${ELO_MODRINTH_USER_AGENT:-3nderXP/elo/1.0.0 (https://github.com/3nderXP/elo)}"

elo_provider_modrinth_require_tools() {
  command -v curl >/dev/null 2>&1 || elo_die "curl is required for Modrinth commands."
  command -v jq >/dev/null 2>&1 || elo_die "jq is required for Modrinth commands."
}

elo_provider_modrinth_request() {
  local endpoint="$1"
  shift
  elo_provider_modrinth_require_tools || return
  curl -fsSL -A "$ELO_MODRINTH_USER_AGENT" "$@" "$ELO_MODRINTH_API$endpoint" || {
    elo_die "Modrinth request failed: $endpoint"
    return 1
  }
}

elo_provider_modrinth_search_response() {
  local query="$1" type="$2" game_version="$3" loader="$4" limit="$5" offset="$6"
  local facets='[]' response

  [[ -n "$type" ]] && facets="$(jq -cn --arg value "project_type:$type" '[[$value]]')"
  if [[ -n "$game_version" && "$game_version" != "unknown" ]]; then
    facets="$(printf '%s' "$facets" | jq -c --arg value "versions:$game_version" '. + [[$value]]')"
  fi
  if [[ "$type" == "mod" && -n "$loader" && "$loader" != "unknown" && "$loader" != "vanilla" ]]; then
    facets="$(printf '%s' "$facets" | jq -c --arg value "categories:$loader" '. + [[$value]]')"
  fi

  response="$(elo_provider_modrinth_request /search --get \
    --data-urlencode "query=$query" --data-urlencode "facets=$facets" \
    --data-urlencode "limit=$limit" --data-urlencode "offset=$offset")" || return
  printf '%s\n' "$response"
}

elo_provider_modrinth_search() {
  local query="$1" type="$2" game_version="$3" loader="$4" limit="$5" response
  response="$(elo_provider_modrinth_search_response \
    "$query" "$type" "$game_version" "$loader" "$limit" 0)" || return
  printf '%s' "$response" | jq -r '.hits[] | [.project_id, .slug, .project_type, .title, (.downloads | tostring)] | @tsv'
}

elo_provider_modrinth_search_page() {
  local query="$1" type="$2" game_version="$3" loader="$4" limit="$5" offset="$6" response
  response="$(elo_provider_modrinth_search_response \
    "$query" "$type" "$game_version" "$loader" "$limit" "$offset")" || return
  printf '%s' "$response" | jq -r '
    (.total_hits // (.hits | length)),
    (.hits[] | [.project_id, .slug, .project_type, .title, (.downloads | tostring)] | @tsv)'
}

elo_provider_modrinth_project_type() {
  local id_or_slug="$1" project
  project="$(elo_provider_modrinth_request "/project/$id_or_slug")" || return
  printf '%s' "$project" | jq -r '.project_type'
}

elo_provider_modrinth_resolve() {
  local id_or_slug="$1" game_version="$2" loader="$3" requested_version="${4:-}" platform="${5:-}"
  local project project_type compatibility_loader="" versions version_args=()

  project="$(elo_provider_modrinth_request "/project/$id_or_slug")" || return
  project_type="$(printf '%s' "$project" | jq -r '.project_type')"
  if [[ "$project_type" == "shader" && -z "$platform" && -z "$requested_version" ]]; then
    elo_die "Shader installation requires --platform iris or --platform optifine."
    return 1
  fi
  if [[ -n "$platform" && "$project_type" != "shader" ]]; then
    elo_die "--platform is supported only for shaders."
    return 1
  fi
  case "$project_type" in
    mod) compatibility_loader="$loader" ;;
    resourcepack) compatibility_loader="minecraft" ;;
    shader) compatibility_loader="$platform" ;;
  esac
  if [[ -n "$requested_version" ]]; then
    versions="$(elo_provider_modrinth_request "/version/$requested_version")" || return
    versions="[$versions]"
  else
    if [[ -n "$game_version" && "$game_version" != "unknown" ]]; then
      version_args+=(--data-urlencode "game_versions=[\"$game_version\"]")
    fi
    if [[ -n "$compatibility_loader" && "$compatibility_loader" != "unknown" && "$compatibility_loader" != "vanilla" ]]; then
      version_args+=(--data-urlencode "loaders=[\"$compatibility_loader\"]")
    fi
    versions="$(elo_provider_modrinth_request "/project/$(printf '%s' "$project" | jq -r '.id')/version" --get "${version_args[@]}")" || return
  fi

  jq -cn --argjson project "$project" --argjson versions "$versions" '
    if ($versions | length) == 0 then error("no compatible version") else
      ($versions[0]) as $version |
      ($version.files | map(select(.primary == true)) | .[0] // $version.files[0]) as $file |
      if $file == null then error("version has no downloadable file") else {
        project_id: $project.id, slug: $project.slug, name: $project.title,
        type: $project.project_type, version_id: $version.id,
        version_number: $version.version_number, filename: $file.filename,
        download_url: $file.url, sha512: ($file.hashes.sha512 // ""),
        dependencies: $version.dependencies, platforms: ($version.loaders // [])
      } end
    end' 2>/dev/null || elo_die "No compatible Modrinth version found for: $id_or_slug"
}

elo_provider_modrinth_get_dependencies() {
  local version_id="$1" version
  version="$(elo_provider_modrinth_request "/version/$version_id")" || return
  printf '%s' "$version" | jq -r '.dependencies[] | select(.dependency_type == "required") | [(.project_id // "-"), (.version_id // "-")] | @tsv'
}

elo_provider_modrinth_download() {
  local version_id="$1" target_dir="$2" version file filename url temporary
  version="$(elo_provider_modrinth_request "/version/$version_id")" || return
  file="$(printf '%s' "$version" | jq -c '(.files | map(select(.primary == true)) | .[0]) // .files[0]')"
  filename="$(printf '%s' "$file" | jq -r '.filename // empty')"
  url="$(printf '%s' "$file" | jq -r '.url // empty')"
  if [[ -z "$filename" || -z "$url" || "$filename" == */* || "$filename" == *$'\n'* ]]; then
    elo_die "Modrinth returned an invalid download file."
    return 1
  fi
  if [[ -e "$target_dir/$filename" || -L "$target_dir/$filename" ]]; then
    elo_die "Addon file already exists: $target_dir/$filename"
    return 1
  fi
  mkdir -p -- "$target_dir"
  temporary="$(mktemp "$target_dir/.elo-download.XXXXXX")"
  if ! curl -fsSL -A "$ELO_MODRINTH_USER_AGENT" "$url" -o "$temporary"; then
    rm -f -- "$temporary"
    elo_die "Addon download failed: $filename"
    return 1
  fi
  mv -- "$temporary" "$target_dir/$filename"
  printf '%s\n' "$filename"
}
