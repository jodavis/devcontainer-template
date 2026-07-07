FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
# Includes: vscode user (UID 1000) with passwordless sudo, curl, wget, jq, etc.

# 1. Newer git (needed for worktree.useRelativePaths, added in git 2.48;
#    Ubuntu 24.04's stock apt git is 2.43).
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# 2. GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# 3. .NET 10 SDK + PowerShell
#    pwsh is required to run playwright.ps1 on Linux.
RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
        -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends dotnet-sdk-10.0 powershell \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# 4. Playwright OS-level Chromium dependencies (not the browser binary itself —
#    that depends on a consumer repo's own build output, see each project's
#    post-create.sh). Ubuntu 24.04 renamed libasound2 -> libasound2t64.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3 \
    libxkbcommon0 libatspi2.0-0 libx11-6 libxcomposite1 libxdamage1 libxext6 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2t64 \
    libxshmfence1 fonts-liberation fonts-noto-color-emoji xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# 5. Node.js LTS (for Claude Code CLI)
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nodesource.gpg] \
        https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# 6. Claude Code CLI (global npm install, accessible to all users)
RUN npm install -g @anthropic-ai/claude-code

# 7. Python 3.12 + test tooling shared by both consumers today.
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --break-system-packages pytest pytest-asyncio pytest-mock

# 8. Shared scripts (settings seeding, agent-plugins clone, settings promotion)
#    and generic settings baselines, baked in outside any named volume so
#    seed-settings.sh can copy them in on first boot without clobbering state.
COPY --chmod=755 scripts/*.sh /usr/local/bin/
COPY defaults/ /home/vscode/.template-defaults/

# git-askpass is deliberately NOT installed here — it's an opt-in Feature
# (see ../../src/git-askpass) because it authenticates as a bot account that's
# only appropriate on some repos, not all.

# worktree.useRelativePaths makes worktrees portable between the container's
# /workspaces path and a host checkout at a different absolute path.
RUN git config --system worktree.useRelativePaths true

USER vscode

# Create ~/.claude as vscode so Docker initialises the named volume with the
# correct ownership. Without this the volume root is owned by root and the
# vscode user cannot write auth credentials after login.
RUN mkdir -p /home/vscode/.claude

WORKDIR /workspaces
SHELL ["/bin/bash", "-l", "-c"]
