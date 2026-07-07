# devcontainer-template

Shared devcontainer images and Features, consumed by [AdaptiveRemote](https://github.com/jodavis/AdaptiveRemote)
and [dev-team-agents](https://github.com/jodavis/dev-team-agents). Structured as a
collection so it can grow to serve future projects without restructuring.

## Layout

- `images/<name>/` — a prebuilt image, published to `ghcr.io/jodavis/devcontainer-template/<name>`.
  Today there's one: `images/base`, a fat image covering both current consumers' toolchains
  (.NET, Playwright OS deps, Node, Claude Code CLI, Python + pytest, git, gh).
- `defaults/` — generic, cross-project-safe settings baselines baked into every image:
  - `claude-settings.json` — global Claude Code defaults (conservative permissions, the
    `agent-plugins` marketplace registration). Deliberately excludes `hooks`, `enabledPlugins`,
    and other project-specific fields — those live only in each consumer's own committed
    `.claude/settings.json`.
  - `srt-settings.json` — sandbox network/filesystem baseline.
  - `sync-manifest.json` — the list of settings surfaces `promote-settings.sh` knows how to
    diff and promote. Add an entry here to make a new settings file promotable.
- `scripts/` — baked into every image's `PATH`:
  - `seed-settings.sh` — copies `defaults/*` into their live locations on first boot, never
    overwriting existing state in a named volume.
  - `clone-agent-plugins.sh` — clones `jodavis/agent-plugins` into `/workspaces/agent-plugins`
    on first boot; never resets an existing checkout.
  - `promote-settings.sh` — on-demand: diffs live settings against the last-promoted
    baseline and opens a PR against this repo with just the new, allow-listed entries.
- `src/<feature-name>/` — an opt-in devcontainer Feature, published to
  `ghcr.io/jodavis/devcontainer-template/<feature-name>`. Today there's one: `git-askpass`,
  a `GIT_ASKPASS` helper for repos where Claude Code should authenticate as a bot account
  rather than as you. Not baked into any image — consumers opt in per-repo via their own
  `devcontainer.json`.

Adding a new image or Feature later is just a new folder — the CI workflows discover and
build/publish everything under `images/` and `src/` automatically.

## Consuming this template

In a consumer's `devcontainer.json`:

```jsonc
{
  "image": "ghcr.io/jodavis/devcontainer-template/base:v1",
  "features": {
    // opt-in only, e.g. on personal repos using a bot GitHub account:
    "ghcr.io/jodavis/devcontainer-template/git-askpass:1": {}
  },
  "mounts": [
    "source=<project>-claude-home,target=/home/vscode/.claude,type=volume",
    "source=agent-plugins-home,target=/workspaces/agent-plugins,type=volume"
  ],
  "containerEnv": {
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}",
    "GH_TOKEN": "${localEnv:GH_TOKEN}",
    "GIT_ASKPASS": "/usr/local/bin/git-askpass" // only if git-askpass Feature is enabled
  },
  "runArgs": ["--name", "vscode-<repo>"]
}
```

Convention: give each consumer's running container a fixed name via
`runArgs: ["--name", "vscode-<repo>"]` (e.g. `vscode-adaptiveremote`) so it's identifiable
in `docker ps` instead of Docker's random `adjective_surname` names. This isn't enforced by
the shared image/Features — it's a per-repo `runArgs` entry each consumer sets itself.

Each consumer's own `post-create.sh` should call `seed-settings.sh` and
`clone-agent-plugins.sh` (both on `PATH` from the image), then do whatever is genuinely
repo-specific (e.g. `dotnet restore`, installing the Playwright browser binary, `pip
install -r requirements.txt`).

## Promoting settings changes

If you approve a new permission or `allowedDomains`/`allowWrite` entry live inside a
running consumer container and want it available by default next time:

```bash
promote-settings.sh        # interactive: shows the diff, asks to confirm each entry
promote-settings.sh --yes  # non-interactive: promotes everything new
```

This opens a PR against this repo containing only the new entries — nothing project-specific
ever gets promoted, because `sync-manifest.json`'s `promotableKeys` is an explicit allow-list.

## Worktree portability

`git config --system worktree.useRelativePaths true` is set in `images/base/Dockerfile`, so
worktrees created inside a container (under `/workspaces/...`) store relative paths and
resolve correctly from a host checkout at a different absolute path too. Requires git ≥2.48
(the image installs git from `ppa:git-core/ppa` for this reason — Ubuntu 24.04's stock git
is 2.43). Worktrees created before this setting was in effect won't be fixed automatically;
run `git worktree repair` on them once.

## Versioning

- Images: tagged `latest`, a major-version pin (`v1` — consumers should track this, not
  `latest`), full semver (`v1.0.0`), and a build date (`YYYY-MM-DD`).
- Features: versioned independently via each `devcontainer-feature.json`'s `version` field.
- All GHCR packages are public — no pull-auth wiring needed by consumers or their CI.

## Known implementation TODOs

- `src/git-askpass/devcontainer-feature.json` declares `containerEnv.GIT_ASKPASS` directly;
  confirm this is actually honored by the Dev Containers spec/tooling on first real use — if
  not, consumers will need to set `GIT_ASKPASS` in their own `devcontainer.json` instead.
- Multi-root Explorer visibility for `/workspaces/agent-plugins` alongside a consumer's own
  workspace folder (generated `.code-workspace` vs. manual "Add Folder to Workspace") hasn't
  been settled — confirm what the Dev Containers extension supports cleanly.
- `enabledPlugins` keys are of the form `<plugin>@<marketplace-name>`. Now that the
  marketplace is consistently named `agent-plugins`, confirm the key suffixes consumers use
  match whatever naming `agent-plugins`' own plugin manifests expect.
