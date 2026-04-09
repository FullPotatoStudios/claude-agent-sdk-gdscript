#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

claude_path="${CLAUDE_BIN:-claude}"
requested_modes=()

while [ "$#" -gt 0 ]; do
	case "$1" in
		--claude-path)
			claude_path="$2"
			shift 2
			;;
		--mode)
			requested_modes+=("$2")
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

cd "${repo_root}"

godot_binary="$(resolve_godot_binary || true)"
if [ -z "${godot_binary}" ]; then
	echo "Godot binary not found. Set GODOT_BIN or install Godot 4.6." >&2
	exit 1
fi

log_dir="${repo_root}/.artifacts/live-cli"
mkdir -p "${log_dir}"

resolved_claude_path=""
if [[ "${claude_path}" == */* ]]; then
	if [ ! -x "${claude_path}" ]; then
		echo "Claude CLI is not executable at: ${claude_path}" >&2
		exit 1
	fi
	resolved_claude_path="${claude_path}"
else
	resolved_claude_path="$(command -v "${claude_path}" || true)"
	if [ -z "${resolved_claude_path}" ]; then
		echo "Claude CLI not found on PATH: ${claude_path}" >&2
		exit 1
	fi
fi

auth_status=""
auth_error=""
auth_error_file="$(mktemp "${TMPDIR:-/tmp}/claude-auth-status.XXXXXX")"
trap 'rm -f "${auth_error_file}"' EXIT

if auth_status="$("${resolved_claude_path}" auth status --json 2>"${auth_error_file}")"; then
	auth_error="$(cat "${auth_error_file}")"
else
	auth_error="$(cat "${auth_error_file}")"
	auth_status=""
fi

if [ -z "${auth_status}" ]; then
	echo "Could not read Claude auth status from the local CLI." >&2
	if [ -n "${auth_error}" ]; then
		echo "${auth_error}" >&2
	fi
	exit 1
fi

if ! AUTH_STATUS_JSON="${auth_status}" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["AUTH_STATUS_JSON"])
if not data.get("loggedIn", False):
	raise SystemExit(1)
PY
then
	echo "Claude CLI is not logged in in the current local environment." >&2
	exit 1
fi

smoke_modes=()
mode_list_log="${log_dir}/list-modes.log"
while IFS= read -r mode; do
	if [ -n "${mode}" ]; then
		smoke_modes+=("${mode}")
	fi
done < <(
	"${godot_binary}" \
		--headless \
		--log-file "${mode_list_log}" \
		--path "${repo_root}" \
		-s res://tools/spikes/phase5_runtime_smoke.gd \
		-- --list-modes \
	| sed -n 's/^MODE //p'
)

if [ "${#smoke_modes[@]}" -eq 0 ]; then
	echo "Could not determine live smoke modes from tools/spikes/phase5_runtime_smoke.gd" >&2
	exit 1
fi

if [ "${#requested_modes[@]}" -gt 0 ]; then
	filtered_modes=()
	for requested_mode in "${requested_modes[@]}"; do
		found=0
		for mode in "${smoke_modes[@]}"; do
			if [ "${mode}" = "${requested_mode}" ]; then
				filtered_modes+=("${mode}")
				found=1
				break
			fi
		done
		if [ "${found}" -eq 0 ]; then
			echo "Unknown live smoke mode: ${requested_mode}" >&2
			exit 1
		fi
	done
	smoke_modes=("${filtered_modes[@]}")
fi

for mode in "${smoke_modes[@]}"; do
	echo "Running live Claude smoke: ${mode}"
	log_file="${log_dir}/${mode}.log"
	"${godot_binary}" \
		--headless \
		--log-file "${log_file}" \
		--path "${repo_root}" \
		-s res://tools/spikes/phase5_runtime_smoke.gd \
		-- --mode="${mode}" --claude-path="${resolved_claude_path}"
done

echo "Live Claude CLI validation passed."
