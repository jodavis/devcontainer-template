#!/usr/bin/env bash
# Clones jodavis/agent-plugins into the shared /workspaces/agent-plugins
# volume on first boot. Never resets an existing checkout, so local
# branches/edits made while working survive container rebuilds and are
# visible from whichever consumer container is opened next.
set -euo pipefail

CLONE_DIR="/workspaces/agent-plugins"

if [ -d "$CLONE_DIR/.git" ]; then
    echo "==> [clone-agent-plugins] $CLONE_DIR already exists — leaving it untouched."
    exit 0
fi

echo "==> [clone-agent-plugins] Cloning jodavis/agent-plugins into $CLONE_DIR..."
gh repo clone jodavis/agent-plugins "$CLONE_DIR"
