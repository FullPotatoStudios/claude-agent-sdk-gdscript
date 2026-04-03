#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

tag_name=""
download_url=""
output_dir=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--tag)
			tag_name="$2"
			shift 2
			;;
		--download-url)
			download_url="$2"
			shift 2
			;;
		--output-dir)
			output_dir="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

cd "${repo_root}"

version="$(read_addon_version)"
if [ -n "${tag_name}" ] && [ "$(strip_tag_prefix "${tag_name}")" != "${version}" ]; then
	echo "Tag ${tag_name} does not match addons/claude_agent_sdk/VERSION (${version})." >&2
	exit 1
fi

tag_name="${tag_name:-$(addon_version_to_tag)}"
output_dir="${output_dir:-${repo_root}/.artifacts/release/${tag_name}}"
mkdir -p "${output_dir}"

if [ -z "${download_url}" ]; then
	if [ -n "${GITHUB_REPOSITORY:-}" ]; then
		download_url="https://github.com/${GITHUB_REPOSITORY}/releases/download/${tag_name}/claude-agent-sdk-gdscript-${tag_name}.zip"
	else
		download_url="https://github.com/FullPotatoStudios/claude-agent-sdk-gdscript/releases/download/${tag_name}/claude-agent-sdk-gdscript-${tag_name}.zip"
	fi
fi

release_notes_path="${output_dir}/RELEASE_NOTES.md"
asset_library_summary_path="${output_dir}/ASSET_LIBRARY_SUMMARY.md"

release_date="$(awk -v version="${version}" '
	$0 ~ "^## \\[" version "\\] - " {
		sub("^## \\[" version "\\] - ", "", $0)
		print
		exit
	}
' CHANGELOG.md)"

if [ -z "${release_date}" ]; then
	echo "Could not read release date for ${version} from CHANGELOG.md" >&2
	exit 1
fi

changelog_section="$(awk -v version="${version}" '
	$0 ~ "^## \\[" version "\\] - " { capture=1; next }
	capture && $0 ~ "^## \\[" { exit }
	capture { print }
' CHANGELOG.md)"

upstream_version="$(rg -o --replace '$1' '^- Version: `([^`]+)`' docs/parity/upstream-ledger.md | head -n 1)"
upstream_commit="$(rg -o --replace '$1' '^- Commit: `([0-9a-f]+)`' docs/parity/upstream-ledger.md | head -n 1)"

cat > "${release_notes_path}" <<EOF
# Claude Agent SDK for GDScript ${tag_name}

Release date: ${release_date}

## Highlights
${changelog_section}

## Compatibility

- Godot \`4.6\`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios

## Install

- direct ZIP install: extract into \`res://addons/claude_agent_sdk/\`
- Godot Asset Library: install from the listing backed by the same GitHub Release ZIP

## Known limitations

- requires a user-installed \`claude\` CLI and existing Claude auth
- mobile, web, and App Store-sandboxed macOS workflows remain unsupported

## Upstream reference

- Python SDK version: ${upstream_version}
- Python SDK commit: ${upstream_commit}
EOF

python3 - "${repo_root}/docs/release/asset-library.json" "${version}" "${download_url}" > "${asset_library_summary_path}" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
version = sys.argv[2]
download_url = sys.argv[3]

print(f"# Asset Library Summary for v{version}\n")
print(f"- Title: {manifest['title']}")
print(f"- Version: {version}")
print(f"- Short description: {manifest['short_description']}")
print(f"- Repository URL: {manifest['repository_url']}")
print(f"- Support URL: {manifest['support_url']}")
print(f"- License URL: {manifest['license_url']}")
print(f"- Download URL: {download_url}")
print("")
print("## Compatibility")
for line in manifest["compatibility"]:
    print(f"- {line}")
print("")
print("## Release assets")
print(f"- Icon: {manifest['icon_path']}")
for path in manifest["screenshot_paths"]:
    print(f"- Screenshot: {path}")
print("")
print("## Manual Asset Library step")
print("Update the listing in the Godot Asset Library UI using the validated values above.")
PY

echo "Rendered release metadata:"
echo "  Release notes: ${release_notes_path}"
echo "  Asset Library summary: ${asset_library_summary_path}"
