#!/usr/bin/env bash

set -euo pipefail

tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${tools_dir}/.." && pwd)"

read_addon_version() {
	tr -d '[:space:]' < "${repo_root}/addons/claude_agent_sdk/VERSION"
}

addon_version_to_tag() {
	printf 'v%s\n' "$(read_addon_version)"
}

strip_tag_prefix() {
	local value="${1:-}"
	printf '%s\n' "${value#v}"
}

resolve_godot_binary() {
	if [ -n "${GODOT_BIN:-}" ]; then
		printf '%s\n' "${GODOT_BIN}"
		return 0
	fi
	if [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		printf '%s\n' "/Applications/Godot.app/Contents/MacOS/Godot"
		return 0
	fi
	if command -v godot4 >/dev/null 2>&1; then
		command -v godot4
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	return 1
}

ensure_gdunit4_installed() {
	if [ -d "${repo_root}/addons/gdUnit4" ]; then
		return 0
	fi
	"${repo_root}/tools/dev/install_gdunit4.sh"
}

write_sha256_file() {
	local artifact_path="$1"
	local output_path="$2"
	local artifact_name
	artifact_name="$(basename "${artifact_path}")"
	if command -v shasum >/dev/null 2>&1; then
		(
			cd "$(dirname "${artifact_path}")"
			shasum -a 256 "${artifact_name}" > "${output_path}"
		)
		return 0
	fi
	if command -v sha256sum >/dev/null 2>&1; then
		(
			cd "$(dirname "${artifact_path}")"
			sha256sum "${artifact_name}" > "${output_path}"
		)
		return 0
	fi
	echo "Neither shasum nor sha256sum is available." >&2
	return 1
}

make_temp_dir() {
	local prefix="${1:-codex-temp}"
	mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX"
}
