#!/usr/bin/env bash
# Asserts the tools baked into images/base are present and sane.
# Run inside the built image by build-publish-images.yml (devcontainers/ci).
set -euo pipefail

check_tool() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: Required tool '$tool' is not installed or not on PATH." >&2
        exit 1
    fi
}

echo 'Checking required tools...'
check_tool git
check_tool gh
check_tool node
check_tool claude
check_tool dotnet
check_tool pwsh
check_tool python3
check_tool jq
check_tool yarn

echo 'Checking yarn runs without a network fetch (Corepack release must be pre-cached)...'
COREPACK_ENABLE_NETWORK=0 yarn --version >/dev/null

echo 'Checking git version >= 2.48 (worktree.useRelativePaths support)...'
GIT_VERSION="$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
GIT_MAJOR="${GIT_VERSION%%.*}"
GIT_MINOR="$(echo "$GIT_VERSION" | cut -d. -f2)"
if [ "$GIT_MAJOR" -lt 2 ] || { [ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -lt 48 ]; }; then
    echo "ERROR: git $GIT_VERSION is older than 2.48; worktree.useRelativePaths is unsupported." >&2
    exit 1
fi

echo 'Checking worktree.useRelativePaths is set system-wide...'
if [ "$(git config --system --get worktree.useRelativePaths)" != "true" ]; then
    echo "ERROR: worktree.useRelativePaths is not set to true in system git config." >&2
    exit 1
fi

echo 'Checking shared scripts are on PATH...'
check_tool seed-settings.sh
check_tool clone-agent-plugins.sh
check_tool promote-settings.sh

echo 'Checking baked defaults are present...'
for f in claude-settings.json srt-settings.json sync-manifest.json; do
    if [ ! -f "/home/vscode/.template-defaults/$f" ]; then
        echo "ERROR: expected default '$f' not found under /home/vscode/.template-defaults/." >&2
        exit 1
    fi
done

echo 'All smoke tests passed.'
