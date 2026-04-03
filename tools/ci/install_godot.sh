#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

version="${GODOT_VERSION:-4.6-stable}"
download_url="${GODOT_DOWNLOAD_URL:-https://github.com/godotengine/godot/releases/download/${version}/Godot_v${version}_linux.x86_64.zip}"
install_root="${GODOT_INSTALL_ROOT:-${RUNNER_TEMP:-${repo_root}/.artifacts/ci}/godot/${version}}"
archive_path="${install_root}/godot.zip"

mkdir -p "${install_root}"

if [ ! -f "${archive_path}" ]; then
	curl -L --fail --output "${archive_path}" "${download_url}"
fi

if ! find "${install_root}" -maxdepth 1 -type f -perm -111 | grep -q .; then
	unzip -oq "${archive_path}" -d "${install_root}"
fi

godot_bin="$(find "${install_root}" -maxdepth 1 -type f -perm -111 | LC_ALL=C sort | head -n 1)"
if [ -z "${godot_bin}" ]; then
	echo "Could not locate an executable Godot binary under ${install_root}" >&2
	exit 1
fi

chmod +x "${godot_bin}"
echo "Installed Godot at ${godot_bin}"

if [ -n "${GITHUB_ENV:-}" ]; then
	printf 'GODOT_BIN=%s\n' "${godot_bin}" >> "${GITHUB_ENV}"
fi

printf '%s\n' "${godot_bin}"
