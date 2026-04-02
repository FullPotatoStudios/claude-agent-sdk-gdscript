#!/usr/bin/env bash

set -eu

VERSION="${GDUNIT4_VERSION:-6.1.2}"
ARCHIVE_URL="https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v${VERSION}.tar.gz"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gdunit4.XXXXXX")"
ARCHIVE_PATH="${TMP_DIR}/gdunit4.tar.gz"
EXTRACT_DIR="${TMP_DIR}/extract"
DEST_DIR="addons/gdUnit4"

if [ -e "${DEST_DIR}" ]; then
	echo "GdUnit4 is already installed at ${DEST_DIR}"
	exit 0
fi

mkdir -p "${EXTRACT_DIR}"
mkdir -p "addons"

echo "Downloading GdUnit4 v${VERSION} from ${ARCHIVE_URL}"
curl -L --fail --output "${ARCHIVE_PATH}" "${ARCHIVE_URL}"

echo "Extracting GdUnit4 into ${DEST_DIR}"
tar -xzf "${ARCHIVE_PATH}" -C "${EXTRACT_DIR}"
cp -R "${EXTRACT_DIR}/gdUnit4-${VERSION}/addons/gdUnit4" "${DEST_DIR}"
chmod +x "${DEST_DIR}/runtest.sh"

echo "Installed GdUnit4 at ${DEST_DIR}"
echo "Temporary files are in ${TMP_DIR}"
