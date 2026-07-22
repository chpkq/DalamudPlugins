#!/usr/bin/env bash

# 根据 GitHub 正式 Release 更新 plugins 目录中的插件版本和下载链接。
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
plugin_dir="$root_dir/plugins"
rules_path="$root_dir/.github/plugin-release-rules.json"

if [[ ! -f "$rules_path" ]]; then
  echo "未找到更新规则: $rules_path" >&2
  exit 1
fi

curl_headers=(--fail --location --silent --show-error --connect-timeout 15 --max-time 60 --header "Accept: application/vnd.github+json")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
fi

get_repo_slug() {
  local repo_url="$1"
  if [[ "$repo_url" =~ ^https://github\.com/([^/]+)/([^/?#]+?)(\.git)?/?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi

  echo "无法从 RepoUrl 解析 GitHub 仓库: $repo_url" >&2
  return 1
}

updated_count=0
skipped_count=0

shopt -s nullglob
for plugin_path in "$plugin_dir"/*.json; do
  internal_name="$(jq -er '.InternalName' "$plugin_path")"
  repo_url="$(jq -er '.RepoUrl' "$plugin_path")"
  rule="$(jq -c --arg internal_name "$internal_name" '.plugins[]? | select(.internalName == $internal_name)' "$rules_path" | head -n 1)"
  tag_prefix="$(jq -r '.tagPrefix // ""' <<<"${rule:-{}}")"
  source_repo="$(jq -r '.sourceRepo // ""' <<<"${rule:-{}}")"

  if [[ -z "$source_repo" ]]; then
    source_repo="$(get_repo_slug "$repo_url")"
  fi

  if ! releases="$(curl "${curl_headers[@]}" "https://api.github.com/repos/${source_repo}/releases?per_page=100")"; then
    echo "警告: 无法读取 $internal_name 的 Release，已跳过" >&2
    ((skipped_count += 1))
    continue
  fi

  # 版本号从 Tag 中提取；例如 tagPrefix 为 v 时接受 v1.2.3.4。
  tag_pattern="^${tag_prefix}(?<version>[0-9]+\\.[0-9]+\\.[0-9]+(?:\\.[0-9]+)?)$"
  if ! latest="$(jq -cer --arg pattern "$tag_pattern" '
      [ .[] | select(.draft | not) | select(.prerelease | not) ]
      | sort_by(.published_at // .created_at)
      | reverse
      | first(.[] | select(.tag_name | test($pattern)))
      | {
          tag: .tag_name,
          version: (.tag_name | capture($pattern).version),
          publishedAt: (.published_at // .created_at)
        }
    ' <<<"$releases")"; then
    echo "警告: $internal_name 没有匹配规则的正式 Release，已跳过" >&2
    ((skipped_count += 1))
    continue
  fi

  tag_name="$(jq -r '.tag' <<<"$latest")"
  assembly_version="$(jq -r '.version | split(".") | . + ["0", "0", "0", "0"] | .[0:4] | join(".")' <<<"$latest")"
  last_update="$(jq -r '.publishedAt | fromdateiso8601 | tostring' <<<"$latest")"
  download_url="https://github.com/${source_repo}/releases/download/${tag_name}/latest.zip"
  temporary_path="$(mktemp)"

  jq \
    --arg assembly_version "$assembly_version" \
    --arg download_url "$download_url" \
    --arg last_update "$last_update" \
    '
      .AssemblyVersion = $assembly_version
      | .DownloadLinkInstall = $download_url
      | .DownloadLinkUpdate = $download_url
      | if .DownloadLinkTesting == null then . else .DownloadLinkTesting = $download_url end
      | .LastUpdate = $last_update
    ' "$plugin_path" > "$temporary_path"

  if cmp -s "$temporary_path" "$plugin_path"; then
    echo "$internal_name 已是最新状态"
    rm -f "$temporary_path"
    continue
  fi

  mv "$temporary_path" "$plugin_path"
  echo "已更新 $internal_name -> $assembly_version（Tag: $tag_name）"
  ((updated_count += 1))
done

echo "更新完成：$updated_count 个插件已更新，$skipped_count 个插件已跳过。"
