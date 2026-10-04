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

# node (for JS-based MCP servers via npx) is already the base image;
# pnpm is added below.
# python3 (above) covers python-based MCP servers.
# openssh-client provides ssh-keygen for SSH-based commit signing —
# `git commit -S` under `gpg.format=ssh` calls `ssh-keygen -Y sign`,
# which reaches the forwarded 1Password SSH agent via SSH_AUTH_SOCK.
# The host's `op-ssh-sign` (a macOS binary set in ~/.private/gitconfig)
# is bypassed inside the container via GIT_CONFIG_PARAMETERS — see
# bin/claude-in-docker.

# pnpm, not npm: it runs no dependency lifecycle scripts unless the package
# is named in --allow-build, and (pnpm 11+) won't resolve a version younger
# than minimumReleaseAge (1 day) — so `claude` here trails npm `latest` by
# about a day. That is the point: a hijacked publish gets caught first.
# npm is used once, script-free, to bootstrap pnpm itself (no deps). Pinned
# exactly: this step gets no release-age delay, so bump it by hand.
ARG PNPM_VERSION=12.9.1
ENV PNPM_HOME=/usr/local/share/pnpm
ENV PATH=$PNPM_HOME/bin:$PATH
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    npm install -g --ignore-scripts "pnpm@$PNPM_VERSION" && pnpm --version

# BuildKit secret mount: reads ~/.npmrc at build time only (never baked into
# the image), for a private registry. A corporate `ignore-scripts=true` there
# doesn't block --allow-build.
#
# @anthropic-ai/claude-code's postinstall picks the platform-native binary,
# which ships as an *optional* dep (~110 MB). Behind a corporate proxy that
# fetch routinely stalls and a failed optional dep is not an install error,
# so `claude --version` is inside the retry: a missing binary retries, then
# fails the build instead of the first run.
#
# CACHE_BUST is set by bin/rebuild-images so a rebuild re-resolves `latest`.
ARG CLAUDE_CODE_VERSION=latest
ARG CACHE_BUST=0
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    --mount=type=cache,target=/root/.cache/pnpm-store,sharing=locked \
    set -eux; \
    for attempt in 1 2 3; do \
        pnpm add -g --store-dir /root/.cache/pnpm-store \
            --allow-build=@anthropic-ai/claude-code \
            "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" \
        && claude --version && break; \
        [ "$attempt" = 3 ] && exit 1; \
        echo "claude-code install attempt $attempt failed; retrying"; sleep 5; \
    done; \
    ln -sf "$PNPM_HOME/bin/claude" /usr/local/bin/claude

ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["claude"]
