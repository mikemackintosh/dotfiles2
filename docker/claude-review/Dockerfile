# claude-review — image used by `bin/claude-in-docker`.
# Runs Claude Code inside a container so --dangerously-skip-permissions
# is contained to a narrow set of host mounts (see bin/claude-in-docker).
FROM node:22-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git openssh-client jq dumb-init \
        netcat-openbsd \
        python3 python3-pip pipx; \
    install -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        docker-ce-cli docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

# node (for JS-based MCP servers via npx) is already the base image.
# python3 (above) covers python-based MCP servers.
# openssh-client provides ssh-keygen for SSH-based commit signing —
# `git commit -S` under `gpg.format=ssh` calls `ssh-keygen -Y sign`,
# which reaches the forwarded 1Password SSH agent via SSH_AUTH_SOCK.
# The host's `op-ssh-sign` (a macOS binary set in ~/.private/gitconfig)
# is bypassed inside the container via GIT_CONFIG_PARAMETERS — see
# bin/claude-in-docker.

# BuildKit secret mount: reads ~/.npmrc at build time only (never
# baked into the image). Required when the host is using a private
# npm registry.
#
# --ignore-scripts=false is required because a corporate ~/.npmrc
# typically sets `ignore-scripts=true` for supply-chain safety, but
# @anthropic-ai/claude-code's postinstall is what downloads the
# platform-native `claude` binary — skip it and `claude` errors out
# with "claude native binary not installed" at runtime.
#
# The platform binary ships as an *optional* dependency
# (@anthropic-ai/claude-code-linux-arm64 etc, ~280 MB). npm treats a
# failed optional dep as success — it just logs "reify failed optional
# dependency" and prints "added 1 package". Behind a corporate Nexus
# proxy a cold-cache fetch of that tarball routinely stalls or drops,
# so the build silently loses `claude`'s binary and only blows up at
# the `claude --version` smoke test. Hence: retry the install, then
# install the native package *explicitly* as a direct dep so any
# remaining failure is loud instead of silent. Node resolves it from
# /usr/local/lib/node_modules just as well as from the nested path.
#
# The manual `node install.cjs` is a belt-and-suspenders fallback in
# case --ignore-scripts=false doesn't fully override the npmrc.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    --mount=type=cache,target=/root/.npm,sharing=locked \
    set -eux; \
    export npm_config_fetch_retries=5 \
           npm_config_fetch_retry_maxtimeout=120000 \
           npm_config_fetch_timeout=600000; \
    for attempt in 1 2 3; do \
        npm install -g --ignore-scripts=false @anthropic-ai/claude-code && break; \
        echo "npm install attempt $attempt failed; retrying"; sleep 5; \
    done; \
    pkg=/usr/local/lib/node_modules/@anthropic-ai/claude-code; \
    ver=$(node -p "require('$pkg/package.json').version"); \
    native="@anthropic-ai/claude-code-linux-$(node -p process.arch)"; \
    node -e "require.resolve('$native/package.json',{paths:['$pkg']})" \
        || npm install -g --ignore-scripts=false "$native@$ver"; \
    if [ -f "$pkg/install.cjs" ]; then node "$pkg/install.cjs" || true; fi; \
    claude --version

ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["claude"]
