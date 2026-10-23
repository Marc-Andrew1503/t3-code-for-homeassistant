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
# libatomic1 is required by the T3 executable. nginx (Debian's build includes
# ngx_http_sub_module) fronts T3 for Home Assistant Ingress; our own
# /etc/nginx/nginx.conf comes with rootfs, so the packaged default site goes.
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
        nginx \
        openssh-client \
        procps \
        ripgrep; \
    rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default /etc/nginx/conf.d/*

# Download an npm registry tarball and verify it against the registry's sha512
# integrity value. Usage: npm_fetch <package> <tarball-basename> <version> <dest>
COPY npm-fetch.sh /usr/local/lib/t3code/npm-fetch.sh

# T3 Code: the GitHub Release archive contains the self-contained executable
# plus its client/ assets and native node_modules next to it. No Node.js
# required. Since 0.1.1 the npm package `t3` is only a launcher that downloads
# this same archive and checks it against the release's SHA256SUMS, as we do.
RUN set -eux; \
    test -n "${T3_VERSION}"; \
    base="https://github.com/pingdotgg/t3code/releases/download/v${T3_VERSION}"; \
    archive="t3-${T3_VERSION}-linux-x64.tar.gz"; \
    curl -fsSL --retry 5 --retry-all-errors -o /tmp/SHA256SUMS "${base}/SHA256SUMS"; \
    curl -fsSL --retry 5 --retry-all-errors -o "/tmp/${archive}" "${base}/${archive}"; \
    awk -v f="${archive}" '$2 == f || $2 == "*" f { print $1 "  /tmp/" f }' /tmp/SHA256SUMS | sha256sum -c -; \
    mkdir -p /opt/t3; \
    tar -xzf "/tmp/${archive}" -C /opt/t3 --strip-components=1; \
    rm -f "/tmp/${archive}" /tmp/SHA256SUMS; \
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
    CMD ["curl", "-fsS", "-o", "/dev/null", "http://127.0.0.1:3773/.well-known/t3/environment"]

WORKDIR /homeassistant
