<img src="assets/icon.svg" width="64" height="64" alt="">

# T3 Code for Home Assistant

[![Add repository to my Home Assistant][badge]][add-repo]
[![Build & Test](https://github.com/Marc-Andrew1503/t3-code-for-homeassistant/actions/workflows/build-test.yaml/badge.svg)](https://github.com/Marc-Andrew1503/t3-code-for-homeassistant/actions/workflows/build-test.yaml)
[![Auto-update](https://github.com/Marc-Andrew1503/t3-code-for-homeassistant/actions/workflows/auto-update.yaml/badge.svg)](https://github.com/Marc-Andrew1503/t3-code-for-homeassistant/actions/workflows/auto-update.yaml)

A Home Assistant add-on that runs the [T3 Code](https://github.com/pingdotgg/t3code) server
(npm package [`t3`](https://www.npmjs.com/package/t3)) together with the
[Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) CLI on your Home Assistant
host. You then connect the T3 Code desktop app to it and let coding agents work directly on your
Home Assistant configuration (`/homeassistant`) and the shared folder (`/share`).

> **Unofficial.** This project is not affiliated with, endorsed by or sponsored by T3 / Ping Labs
> (ping.gg) or Anthropic. "T3 Code" and "Claude Code" belong to their respective owners. This
> repository only packages the published npm releases as a Home Assistant add-on.

## Installation

1. Click the badge above (or use this link):
   [![Add repository to my Home Assistant][badge]][add-repo]

   Or add it manually in Home Assistant under **Settings -> Add-ons -> Add-on store -> menu (top
   right) -> Repositories** and enter:

   ```text
   https://github.com/Marc-Andrew1503/t3-code-for-homeassistant
   ```

2. Open the add-on store, select **T3 Code** and click **Install**.
3. Start the add-on. State (projects, sessions, credentials) is kept in the add-on's persistent
   `/data` volume and survives restarts and updates.

The image is published to GitHub Container Registry
(`ghcr.io/Marc-Andrew1503/t3code-amd64`), so the Supervisor pulls a ready-made image and no
build happens on your Home Assistant host. Currently only `amd64` is supported.

## Pairing

1. Start the add-on and open its **Log** tab. It prints a one-time pairing token.
2. In the T3 Code desktop app, add a remote environment and connect to
   `http://<HA-IP>:3773` (replace `<HA-IP>` with the address of your Home Assistant host).
3. Enter the pairing token from the add-on log when asked.

The server speaks plain HTTP on port `3773/tcp`. Do not expose that port to the internet; use your
LAN, a VPN such as WireGuard or Tailscale, or a reverse proxy that adds TLS and authentication.
See the add-on's own documentation tab for configuration options.

## Security notes

- Coding agents run inside the add-on with write access to `/homeassistant` (your configuration
  directory) and `/share`. An agent can break your configuration, create or delete automations and
  read secrets stored in `secrets.yaml`. **Keep regular backups** (Settings -> System -> Backups)
  and consider a Git repository for your configuration.
- Anyone who can reach port 3773 and holds a valid pairing token can run agents on your host.
  Treat the token like a password.
- Agent credentials (for example your Claude login or API key) are stored in `/data` inside the
  add-on and are included in Home Assistant backups of the add-on.

## How updates work

New releases of T3 Code and Claude Code are picked up automatically, tested and published without
any manual step:

```text
   every 6 hours / manual run
              |
              v
  +-----------------------------+   nothing new
  | check: npm view t3 / claude |---------------------> (release job only
  | scripts/check-upstream.sh   |                        retries a missed release)
  +-----------------------------+
              | new stable version
              v
  push branch auto-update/<version>
              |
              v
  +-----------------------------+      failure
  | test: lint + docker build + |----------------------> open/update issue
  | tests/smoke.sh              |                        "auto-update-failed",
  +-----------------------------+                        main stays untouched
              | green
              v
  fast-forward main to the tested commit
              |
              v
  +-----------------------------+
  | release: push image to GHCR |
  | (:<version>, :latest), git  |
  | tag v<version>, GH release  |
  +-----------------------------+
              |
              v
  Home Assistant shows the add-on update
```

Add-on versions follow upstream:

| Change                    | Add-on version                                                   |
| ------------------------- | ---------------------------------------------------------------- |
| New T3 Code release `V`   | `V` (for example `0.0.46`)                                       |
| Only Claude Code changed  | `<T3 version>.<n>` (`0.0.45` -> `0.0.45.1` -> `0.0.45.2`, reset on the next T3 bump) |

Only stable releases are tracked (the npm `latest` dist-tag, never preview or nightly builds).
Because commits made with the default `GITHUB_TOKEN` do not trigger other workflows, the
`auto-update` workflow calls the `build-test` and `release` workflows explicitly instead of relying
on push events.

## Development

Requirements: Docker, [`yq`](https://github.com/mikefarah/yq) v4, `jq`, `npm`, and optionally
[`shellcheck`](https://www.shellcheck.net/) and [`actionlint`](https://github.com/rhysd/actionlint).

```bash
# Build the image exactly like CI does (versions come from t3code/build.yaml)
scripts/read-config.sh   # prints build_from, T3/Claude versions and build args
docker build \
  --build-arg BUILD_FROM="$(yq '.build_from.amd64' t3code/build.yaml)" \
  --build-arg T3_VERSION="$(yq '.args.T3_VERSION' t3code/build.yaml)" \
  --build-arg CLAUDE_CODE_VERSION="$(yq '.args.CLAUDE_CODE_VERSION' t3code/build.yaml)" \
  -t local/t3code-amd64:dev t3code/

# Smoke test the image (starts it, checks the web UI, versions and a restart)
tests/smoke.sh local/t3code-amd64:dev

# Check for upstream updates without touching any file
scripts/check-upstream.sh --dry-run

# Lint and unit tests
scripts/lint-shell.sh
tests/check-upstream.test.sh
actionlint
```

| Path                                | Purpose                                                      |
| ----------------------------------- | ------------------------------------------------------------ |
| `t3code/`                           | The add-on (config, Dockerfile, rootfs, docs, changelog)     |
| `scripts/check-upstream.sh`         | Detects new upstream versions and updates the add-on files   |
| `scripts/read-config.sh`            | Reads build settings for CI                                  |
| `scripts/changelog-section.sh`      | Extracts release notes from `t3code/CHANGELOG.md`            |
| `tests/smoke.sh`                    | Container smoke test                                         |
| `.github/workflows/build-test.yaml` | Lint, build and smoke test (PRs, branches, reusable)         |
| `.github/workflows/auto-update.yaml`| Scheduled upstream check and automatic release               |
| `.github/workflows/release.yaml`    | Publishes the image, tag and GitHub release                  |

## License

[MIT](LICENSE). T3 Code is also MIT licensed; Claude Code is subject to Anthropic's terms.

[badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[add-repo]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FMarc-Andrew1503%2Ft3-code-for-homeassistant
