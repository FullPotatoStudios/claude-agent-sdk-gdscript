#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

tag_name=""
create_tag=0

while [ "$#" -gt 0 ]; do
	case "$1" in
		--tag)
			tag_name="$2"
			shift 2
			;;
		--create-tag)
			create_tag=1
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

cd "${repo_root}"

tag_name="${tag_name:-$(addon_version_to_tag)}"

"${repo_root}/tools/release/verify_release_metadata.sh" --tag "${tag_name}"
"${repo_root}/tools/dev/run_push_checks.sh" --artifact-dir "${repo_root}/.artifacts/release/${tag_name}"
"${repo_root}/tools/release/validate_live_cli.sh"
"${repo_root}/tools/release/check_upstream_diff.sh"
"${repo_root}/tools/release/render_release_metadata.sh" --tag "${tag_name}" --output-dir "${repo_root}/.artifacts/release/${tag_name}"

if [ "${create_tag}" -eq 1 ]; then
	if git rev-parse -q --verify "refs/tags/${tag_name}" >/dev/null 2>&1; then
		echo "Tag ${tag_name} already exists." >&2
		exit 1
	fi
	git tag -a "${tag_name}" -m "Release ${tag_name}"
	echo "Created annotated tag ${tag_name}"
fi

echo "Release preparation passed for ${tag_name}."
