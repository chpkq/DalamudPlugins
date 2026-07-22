#!/usr/bin/env bash

# Builds the public Dalamud repository index from plugins/*.json.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
plugin_dir="$root_dir/plugins"
output="$root_dir/repo.json"
check_only=false

if [[ "${1:-}" == "--check" ]]; then
  check_only=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 2
fi

files=()
for file in "$plugin_dir"/*.json; do
  [[ -e "$file" ]] && files+=("$file")
done

filter='
  . as $plugin |
  ["Author", "Name", "Description", "InternalName", "AssemblyVersion", "RepoUrl", "ApplicableVersion", "DalamudApiLevel", "Punchline", "DownloadLinkInstall", "DownloadLinkUpdate", "LastUpdate"] as $required |
  if type != "object" then error("entry must be a JSON object") else . end |
  if all($required[]; . as $key | $plugin | has($key) and .[$key] != "") then . else error("missing a required field") end |
  if all(["DownloadLinkInstall", "DownloadLinkUpdate", "RepoUrl"][]; . as $key | $plugin[$key] | type == "string" and test("^https?://")) then . else error("URLs must be absolute HTTP(S) URLs") end |
  if ($plugin.LastUpdate | tostring | test("^[0-9]+$")) then . else error("LastUpdate must be a Unix timestamp") end'

if [[ ${#files[@]} -gt 0 ]]; then
  for file in "${files[@]}"; do
    jq -e "$filter" "$file" >/dev/null
  done
fi

temporary_output="$(mktemp)"
trap 'rm -f "$temporary_output"' EXIT

if [[ ${#files[@]} -eq 0 ]]; then
  printf '[]\n' >"$temporary_output"
else
  jq -s '.' "${files[@]}" >"$temporary_output"
fi

if "$check_only"; then
  cmp -s "$temporary_output" "$output" || {
    echo "repo.json is out of date; run: bash scripts/build-repo.sh" >&2
    exit 1
  }
  echo "repo.json is valid (${#files[@]} plugin(s))."
else
  mv "$temporary_output" "$output"
  trap - EXIT
  echo "Wrote repo.json with ${#files[@]} plugin(s)."
fi
