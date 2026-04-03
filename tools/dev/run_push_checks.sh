#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

artifact_dir=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--artifact-dir)
			artifact_dir="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

cd "${repo_root}"

ensure_gdunit4_installed
"${repo_root}/tools/dev/run_tests.sh"

if [ -z "${artifact_dir}" ]; then
	artifact_dir="$(make_temp_dir "claude-agent-sdk-push-checks")"
fi

"${repo_root}/tools/release/build_release.sh" --allow-dirty --output-dir "${artifact_dir}"

version="$(read_addon_version)"
artifact_path="${artifact_dir}/claude-agent-sdk-gdscript-v${version}.zip"
"${repo_root}/tools/release/validate_release.sh" --artifact "${artifact_path}"

echo "Push checks passed."
