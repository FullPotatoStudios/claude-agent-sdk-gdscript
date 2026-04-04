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

search_regex_in_file() {
	local pattern="$1"
	local file_path="$2"
	if command -v rg >/dev/null 2>&1; then
		rg -q -- "${pattern}" "${file_path}"
		return $?
	fi
	grep -Eq -- "${pattern}" "${file_path}"
}

search_fixed_in_file() {
	local needle="$1"
	local file_path="$2"
	if command -v rg >/dev/null 2>&1; then
		rg -F -q -- "${needle}" "${file_path}"
		return $?
	fi
	grep -Fq -- "${needle}" "${file_path}"
}

extract_first_backtick_value() {
	local prefix="$1"
	local file_path="$2"

	awk -v prefix="${prefix}" '
		index($0, prefix) == 1 {
			split($0, parts, "`")
			if (length(parts) >= 3) {
				print parts[2]
				exit
			}
		}
	' "${file_path}"
}

run_godot_import_filtered() {
	local output_file
	output_file="$(mktemp "${TMPDIR:-/tmp}/godot-import.XXXXXX")"
	local status=0

	if "$@" >"${output_file}" 2>&1; then
		python3 - "${output_file}" <<'PY'
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
filtered = []
index = 0
while index < len(lines):
    line = lines[index]
    if line.startswith("ERROR: Could not create ObjectDB Snapshots directory:"):
        next_line = lines[index + 1] if index + 1 < len(lines) else ""
        if "_get_and_create_snapshot_storage_dir" in next_line:
            index += 2
            continue
    filtered.append(line)
    index += 1

for line in filtered:
    print(line)
PY
	else
		status=$?
		cat "${output_file}"
	fi

	rm -f "${output_file}"
	return "${status}"
}
