#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

required_paths=(
	"README.md"
	"AGENTS.md"
	"CHANGELOG.md"
	"docs/contributing/workflow.md"
	"docs/contributing/maintainer-workflow.md"
	"docs/contributing/testing.md"
	"docs/contributing/integration.md"
	"docs/contributing/ui-panel.md"
	"docs/release/install.md"
	"docs/release/packaging.md"
	"docs/release/release-process.md"
	"docs/release/asset-library.md"
	"docs/release/release-notes-template.md"
	"docs/release/asset-library.json"
	"docs/release/assets/README.md"
	"docs/release/assets/chat-panel-preview.png"
	"docs/release/assets/addon-icon.svg"
	"docs/parity/feature-matrix.md"
	"docs/parity/upstream-ledger.md"
	"docs/roadmap/roadmap.md"
	"addons/claude_agent_sdk/README.md"
	"addons/claude_agent_sdk/VERSION"
	"addons/claude_agent_sdk/LICENSE.txt"
)

cd "${repo_root}"

missing=0
for path in "${required_paths[@]}"; do
	if [ ! -e "${path}" ]; then
		echo "Missing required documentation or asset path: ${path}" >&2
		missing=1
	fi
done

if [ "${missing}" -ne 0 ]; then
	exit 1
fi

echo "Documentation and release asset paths look complete."
