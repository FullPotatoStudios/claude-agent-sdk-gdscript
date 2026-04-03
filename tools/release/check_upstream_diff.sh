#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

upstream_dir="${UPSTREAM_CLAUDE_AGENT_SDK_PYTHON_DIR:-${repo_root}/../claude-agent-sdk-python}"

if [ ! -d "${upstream_dir}/.git" ]; then
	echo "Upstream sibling checkout not found: ${upstream_dir}" >&2
	exit 1
fi

pinned_commit="$(rg -o --replace '$1' '^- Commit: `([0-9a-f]+)`' "${repo_root}/docs/parity/upstream-ledger.md" | head -n 1)"
if [ -z "${pinned_commit}" ]; then
	echo "Could not read pinned upstream commit from docs/parity/upstream-ledger.md" >&2
	exit 1
fi

current_commit="$(git -C "${upstream_dir}" rev-parse HEAD)"

echo "Pinned upstream commit:  ${pinned_commit}"
echo "Current upstream commit: ${current_commit}"
echo "Upstream repo:           ${upstream_dir}"
echo

if [ "${pinned_commit}" = "${current_commit}" ]; then
	echo "No upstream drift detected."
	exit 0
fi

scoped_paths=(
	"src/claude_agent_sdk"
	"examples"
	"tests"
	"e2e-tests"
)

echo "Scoped commits since the pinned baseline:"
git -C "${upstream_dir}" log --oneline "${pinned_commit}..${current_commit}" -- "${scoped_paths[@]}"
echo
echo "Scoped diff stat:"
git -C "${upstream_dir}" diff --stat "${pinned_commit}..${current_commit}" -- "${scoped_paths[@]}"
