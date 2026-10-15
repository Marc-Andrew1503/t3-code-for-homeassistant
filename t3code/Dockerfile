# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
ARG BUILD_FROM
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ARG T3_VERSION
ARG CLAUDE_CODE_VERSION
ARG BUILD_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Tools that agents (and T3 itself) expect to find on PATH.
# libatomic1 is required by the T3 executable.
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        less \
        libatomic1 \
        nano \
        openssh-client \
        procps \
        ripgrep; \
    rm -rf /var/lib/apt/lists/*

# Download an npm registry tarball and verify it against the registry's sha512
# integrity value. Usage: npm_fetch <package> <tarball-basename> <version> <dest>
COPY npm-fetch.sh /usr/local/lib/t3code/npm-fetch.sh

# T3 Code: the platform package contains the self-contained executable plus
# its client/ assets and native node_modules next to it. No Node.js required.
RUN set -eux; \
    test -n "${T3_VERSION}"; \
    mkdir -p /opt/t3; \
    bash /usr/local/lib/t3code/npm-fetch.sh "@t3code/t3-linux-x64" "t3-linux-x64" "${T3_VERSION}" /tmp/t3.tgz; \
    tar -xzf /tmp/t3.tgz -C /opt/t3 --strip-components=1; \
    rm -f /tmp/t3.tgz; \
    ln -s /opt/t3/t3 /usr/local/bin/t3; \
    t3 --version | grep -qF "${T3_VERSION}"

# Claude Code: native glibc binary from the platform package (no Node.js).
RUN set -eux; \
    test -n "${CLAUDE_CODE_VERSION}"; \
    mkdir -p /tmp/claude; \
    bash /usr/local/lib/t3code/npm-fetch.sh "@anthropic-ai/claude-code-linux-x64" "claude-code-linux-x64" "${CLAUDE_CODE_VERSION}" /tmp/claude.tgz; \
    tar -xzf /tmp/claude.tgz -C /tmp/claude --strip-components=1 package/claude; \
    install -m 0755 /tmp/claude/claude /usr/local/bin/claude; \
    rm -rf /tmp/claude /tmp/claude.tgz; \
    claude --version

COPY rootfs /

# Persistent state lives in /data (survives add-on updates).
# DISABLE_AUTOUPDATER: the add-on release pipeline updates Claude Code.
ENV HOME=/data/home \
    T3CODE_HOME=/data/t3 \
    DISABLE_AUTOUPDATER=1 \
    TERM=xterm-256color

LABEL \
    io.hass.type="addon" \
    io.hass.arch="amd64" \
    io.hass.version="${BUILD_VERSION:-${T3_VERSION}}" \
    io.hass.name="T3 Code" \
    io.hass.description="T3 Code server with Claude Code for Home Assistant" \
    org.opencontainers.image.title="T3 Code for Home Assistant" \
    org.opencontainers.image.licenses="MIT"

# Lets the Supervisor restart the add-on when the server stops responding.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:3773/.well-known/t3/environment >/dev/null || exit 1

WORKDIR /homeassistant
