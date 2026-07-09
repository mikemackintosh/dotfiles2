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
# The manual `node install.cjs` at the end is a belt-and-suspenders
# fallback in case the CLI flag doesn't fully override the npmrc
# on some npm versions.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    set -eux; \
    npm install -g --ignore-scripts=false @anthropic-ai/claude-code; \
    if [ -f /usr/local/lib/node_modules/@anthropic-ai/claude-code/install.cjs ]; then \
        node /usr/local/lib/node_modules/@anthropic-ai/claude-code/install.cjs || true; \
    fi; \
    claude --version

ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["claude"]
