#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -m 755 "$SCRIPT_DIR/git-askpass.sh" /usr/local/bin/git-askpass

echo "git-askpass installed to /usr/local/bin/git-askpass."
