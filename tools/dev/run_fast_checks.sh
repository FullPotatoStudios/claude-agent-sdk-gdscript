#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

cd "${repo_root}"

git diff --check --cached

while IFS= read -r script_path; do
	bash -n "${script_path}"
done < <(find tools .githooks -type f \( -name '*.sh' -o -path '.githooks/*' \) 2>/dev/null | LC_ALL=C sort)

"${repo_root}/tools/dev/check_docs.sh"

echo "Fast checks passed."
