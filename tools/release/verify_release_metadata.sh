#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

allow_non_main=0
allow_dirty=0
tag_name=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--allow-non-main)
			allow_non_main=1
			shift
			;;
		--allow-dirty)
			allow_dirty=1
			shift
			;;
		--tag)
			tag_name="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

cd "${repo_root}"

branch_name="$(git branch --show-current)"
if [ "${allow_non_main}" -ne 1 ] && [ "${branch_name}" != "main" ]; then
	echo "Release metadata verification must run from main. Current branch: ${branch_name:-detached}" >&2
	exit 1
fi

if [ "${allow_dirty}" -ne 1 ] && ! git diff --quiet --ignore-submodules HEAD --; then
	echo "Refusing to verify release metadata from a dirty worktree." >&2
	exit 1
fi

version="$(read_addon_version)"
if [ -z "${version}" ]; then
	echo "Addon version is empty." >&2
	exit 1
fi

if [ -n "${tag_name}" ] && [ "$(strip_tag_prefix "${tag_name}")" != "${version}" ]; then
	echo "Tag ${tag_name} does not match addons/claude_agent_sdk/VERSION (${version})." >&2
	exit 1
fi

if ! rg -q "^## \\[${version//./\\.}\\]" "${repo_root}/CHANGELOG.md"; then
	echo "CHANGELOG.md is missing a section for version ${version}." >&2
	exit 1
fi

if ! rg -q "^- Local addon version: \`${version}\`" "${repo_root}/docs/parity/upstream-ledger.md"; then
	echo "docs/parity/upstream-ledger.md does not record local addon version ${version}." >&2
	exit 1
fi

"${repo_root}/tools/dev/check_docs.sh"

python3 - "${repo_root}/docs/release/asset-library.json" "${repo_root}" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
data = json.loads(manifest_path.read_text())
required_keys = [
    "title",
    "short_description",
    "compatibility",
    "repository_url",
    "support_url",
    "license_url",
    "icon_path",
    "screenshot_paths",
    "download_url_pattern",
]
missing = [key for key in required_keys if key not in data]
if missing:
    raise SystemExit(f"Missing asset-library metadata keys: {', '.join(missing)}")
if not data["screenshot_paths"]:
    raise SystemExit("asset-library.json must list at least one screenshot path")
for rel_path in [data["icon_path"], *data["screenshot_paths"]]:
    if not (repo_root / rel_path).exists():
        raise SystemExit(f"Referenced Asset Library asset is missing: {rel_path}")
PY

required_phrases=(
	'Godot `4.6`'
	'desktop/editor workflows supported'
	'exported macOS support limited to the validated unsandboxed scenarios'
	'user-installed `claude` CLI'
)

doc_targets=(
	"README.md"
	"docs/release/install.md"
	"docs/release/release-process.md"
	"docs/release/asset-library.md"
)

for phrase in "${required_phrases[@]}"; do
	for path in "${doc_targets[@]}"; do
		if ! rg -F -q "${phrase}" "${repo_root}/${path}"; then
			echo "Missing required release wording in ${path}: ${phrase}" >&2
			exit 1
		fi
	done
done

echo "Release metadata verification passed for version ${version}."
