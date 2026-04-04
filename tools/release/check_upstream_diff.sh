#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

skip_if_missing=0
fail_on_drift=0
summary_file=""
upstream_dir="${UPSTREAM_CLAUDE_AGENT_SDK_PYTHON_DIR:-${repo_root}/../claude-agent-sdk-python}"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--skip-if-missing)
			skip_if_missing=1
			shift
			;;
		--fail-on-drift)
			fail_on_drift=1
			shift
			;;
		--summary-file)
			summary_file="$2"
			shift 2
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

if [ ! -d "${upstream_dir}/.git" ]; then
	if [ "${skip_if_missing}" -eq 1 ]; then
		echo "Skipping upstream drift check; upstream checkout not found: ${upstream_dir}"
		exit 0
	fi
	echo "Upstream sibling checkout not found: ${upstream_dir}" >&2
	exit 1
fi

pinned_commit="$(extract_first_backtick_value "- Commit: " "${repo_root}/docs/parity/upstream-ledger.md")"
if [ -z "${pinned_commit}" ]; then
	echo "Could not read pinned upstream commit from docs/parity/upstream-ledger.md" >&2
	exit 1
fi

current_commit="$(git -C "${upstream_dir}" rev-parse HEAD)"

output="$(
	echo "Pinned upstream commit:  ${pinned_commit}"
	echo "Current upstream commit: ${current_commit}"
	echo "Upstream repo:           ${upstream_dir}"
	echo
)"

if [ "${pinned_commit}" = "${current_commit}" ]; then
	output="${output}No upstream drift detected.
"
	if [ -n "${summary_file}" ]; then
		printf '%s' "${output}" > "${summary_file}"
	fi
	printf '%s' "${output}"
	exit 0
fi

scoped_paths=(
	"src/claude_agent_sdk"
	"examples"
	"tests"
	"e2e-tests"
)

output="${output}Scoped commits since the pinned baseline:
$(git -C "${upstream_dir}" log --oneline "${pinned_commit}..${current_commit}" -- "${scoped_paths[@]}")

Scoped diff stat:
$(git -C "${upstream_dir}" diff --stat "${pinned_commit}..${current_commit}" -- "${scoped_paths[@]}")
"

if [ -n "${summary_file}" ]; then
	printf '%s' "${output}" > "${summary_file}"
fi

printf '%s' "${output}"

if [ "${fail_on_drift}" -eq 1 ]; then
	exit 2
fi
