#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

allow_dirty=0
output_dir=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--allow-dirty)
			allow_dirty=1
			shift
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

if [ "${allow_dirty}" -ne 1 ] && ! git diff --quiet --ignore-submodules HEAD --; then
	echo "Refusing to build a release from a dirty worktree. Commit or pass --allow-dirty." >&2
	exit 1
fi

version="$(read_addon_version)"
if [ -z "${version}" ]; then
	echo "Addon version is empty." >&2
	exit 1
fi

artifact_root="${output_dir:-${repo_root}/.artifacts/release/v${version}}"
artifact_root="$(mkdir -p "${artifact_root}" && cd "${artifact_root}" && pwd)"
artifact_name="claude-agent-sdk-gdscript-v${version}.zip"
artifact_path="${artifact_root}/${artifact_name}"
checksum_path="${artifact_root}/SHA256SUMS.txt"

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/claude-agent-sdk-release-staging.XXXXXX")"
cleanup() {
	rm -rf "${staging_dir}"
}
trap cleanup EXIT

mkdir -p "${staging_dir}/addons"
cp -R "${repo_root}/addons/claude_agent_sdk" "${staging_dir}/addons/"
find "${staging_dir}/addons/claude_agent_sdk" -exec touch -t 202001010000 {} +

(
	cd "${staging_dir}"
	find "addons/claude_agent_sdk" -print | LC_ALL=C sort | zip -X -q "${artifact_path}" -@
)

write_sha256_file "${artifact_path}" "${checksum_path}"

echo "Built release artifact:"
echo "  Version: ${version}"
echo "  ZIP: ${artifact_path}"
echo "  SHA256: ${checksum_path}"
