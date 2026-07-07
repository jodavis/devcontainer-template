#!/usr/bin/env bash
# Seeds generic settings baselines into their live locations on first boot.
# Never overwrites an existing destination file, so state persisted in a
# named volume survives container rebuilds. Safe to call on every
# post-create run.
set -euo pipefail

DEFAULTS_DIR="/home/vscode/.template-defaults"

seed_if_absent() {
    local src="$1"
    local dest="$2"
    if [ -f "$dest" ]; then
        echo "==> [seed-settings] $dest already exists — not overwriting."
        return
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "==> [seed-settings] Seeded $dest from $(basename "$src")."
}

seed_if_absent "$DEFAULTS_DIR/claude-settings.json" "$HOME/.claude/settings.json"
seed_if_absent "$DEFAULTS_DIR/srt-settings.json" "$HOME/.srt-settings.json"
