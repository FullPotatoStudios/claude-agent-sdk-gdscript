#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"

cd "${repo_root}"

chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks

echo "Installed repo-managed git hooks via core.hooksPath=.githooks"
echo "To uninstall, run: git config --unset core.hooksPath"
