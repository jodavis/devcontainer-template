#!/usr/bin/env bash
# On-demand tool: diffs settings you've approved live in this container
# against the last-known-promoted baseline, and opens a PR against
# devcontainer-template with just the newly-added, allow-listed entries.
#
# Only ever touches the array fields listed in each sync-manifest.json
# entry's promotableKeys (e.g. permissions.allow, network.allowedDomains).
# hooks / enabledPlugins / extraKnownMarketplaces / mcpServers are never
# read or written by this script — they stay project-local by design.
set -euo pipefail

AUTO_YES=false
if [ "${1:-}" == "--yes" ]; then
    AUTO_YES=true
fi

MANIFEST="$HOME/.template-defaults/sync-manifest.json"
REPO_DIR="$HOME/.cache/devcontainer-template-promote"
REPO_SLUG="jodavis/devcontainer-template"

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: manifest not found at $MANIFEST" >&2
    exit 1
fi

expand_path() {
    eval echo "$1"
}

echo "==> [promote-settings] Syncing local checkout of $REPO_SLUG..."
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" fetch origin
    git -C "$REPO_DIR" checkout main
    git -C "$REPO_DIR" reset --hard origin/main
else
    gh repo clone "$REPO_SLUG" "$REPO_DIR"
fi

BRANCH="promote-settings/$(date +%Y%m%d-%H%M%S)"
CHANGED=false
SUMMARY=""

PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo unknown)")"

entry_count=$(jq 'length' "$MANIFEST")
for i in $(seq 0 $((entry_count - 1))); do
    entry=$(jq -c ".[$i]" "$MANIFEST")
    name=$(echo "$entry" | jq -r '.name')
    live_path=$(expand_path "$(echo "$entry" | jq -r '.livePath')")
    baseline_path=$(expand_path "$(echo "$entry" | jq -r '.baselinePath')")
    template_rel_path=$(echo "$entry" | jq -r '.templateRelPath')
    template_path="$REPO_DIR/$template_rel_path"

    if [ ! -f "$live_path" ]; then
        echo "==> [promote-settings] [$name] $live_path does not exist — skipping."
        continue
    fi

    if [ ! -f "$baseline_path" ]; then
        echo "==> [promote-settings] [$name] No local baseline yet — seeding from current template state."
        mkdir -p "$(dirname "$baseline_path")"
        cp "$template_path" "$baseline_path"
    fi

    keys=$(echo "$entry" | jq -r '.promotableKeys[]')
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        live_arr=$(jq --arg k "$key" -c 'getpath($k | split("."))  // []' "$live_path")
        base_arr=$(jq --arg k "$key" -c 'getpath($k | split("."))  // []' "$baseline_path")
        delta=$(jq -n --argjson live "$live_arr" --argjson base "$base_arr" '$live - $base')

        if [ "$delta" == "[]" ]; then
            continue
        fi

        echo ""
        echo "==> [promote-settings] [$name] New entries for '$key':"
        echo "$delta" | jq -r '.[] | "    + " + (. | tostring)'

        proceed=true
        if [ "$AUTO_YES" != "true" ]; then
            read -r -p "    Promote these to $template_rel_path? [y/N] " answer
            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                proceed=false
            fi
        fi

        if [ "$proceed" != "true" ]; then
            echo "    Skipped."
            continue
        fi

        merged=$(jq --arg k "$key" --argjson add "$delta" \
            '($k | split(".")) as $p | setpath($p; ((getpath($p) // []) + $add | unique))' \
            "$template_path")
        echo "$merged" > "$template_path"
        cp "$template_path" "$baseline_path"
        CHANGED=true
        SUMMARY="$SUMMARY- \`$name\`: added \`$key\` entries: $(echo "$delta" | jq -c '.')"$'\n'
    done <<< "$keys"
done

if [ "$CHANGED" != "true" ]; then
    echo ""
    echo "==> [promote-settings] Nothing to promote."
    exit 0
fi

echo ""
echo "==> [promote-settings] Opening PR against $REPO_SLUG..."
git -C "$REPO_DIR" checkout -b "$BRANCH"
git -C "$REPO_DIR" add -A
git -C "$REPO_DIR" commit -m "Promote settings from $PROJECT_NAME container"
git -C "$REPO_DIR" push -u origin "$BRANCH"

gh pr create \
    --repo "$REPO_SLUG" \
    --head "$BRANCH" \
    --title "Promote settings from $PROJECT_NAME container" \
    --body "$(printf 'Settings approved live in the %s devcontainer, promoted to the shared template.\n\n%s' "$PROJECT_NAME" "$SUMMARY")"

echo "==> [promote-settings] Done."
