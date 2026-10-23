# T3 Code for Home Assistant

This repo packages the [T3 Code](https://github.com/pingdotgg/t3code) server (npm `t3`) together with the Claude Code CLI as a Home Assistant add-on. Home Assistant OS becomes a T3 Code remote environment: a user pairs their T3 Code app with it and lets Claude Code agents work on their Home Assistant configuration.

It is unofficial and only repackages published npm releases. Bugs in T3 Code itself belong upstream at `pingdotgg/t3code`.

- One add-on, `t3code/`. `amd64` only. Clients connect directly on port `3773/tcp` and pair with a one-time code printed in the add-on log. Home Assistant also shows a "T3 Code" sidebar panel (Ingress, admins only, auto sign-in): an nginx on port 8099 re-roots the T3 web UI under the ingress prefix.
- `/homeassistant` (the HA config folder) and `/share` are mapped read-write. All state lives in `/data` (`HOME=/data/home`, `T3CODE_HOME=/data/t3`) and survives updates.
- The image is built by CI and published to GHCR (`ghcr.io/marc-andrew1503/t3code-amd64`). The Supervisor pulls it; nothing is built on the user's HA host.
- Versions of T3 Code and Claude Code are bumped automatically by `auto-update.yaml` and released by `release.yaml`.

## What we never compromise on

This add-on is small on purpose. These are the things we protect.

### 1. Open at the core

Everything is plain scripts, YAML and one Dockerfile. No hidden build steps, no vendored binaries. Packages are fetched from the npm registry and verified against their sha512 integrity (`t3code/npm-fetch.sh`). The T3 Code executable comes from its GitHub Release and is verified against the release's `SHA256SUMS`. Keep it readable by someone who has never seen the repo.

### 2. Performance without compromise

Small image, fast start. A Home Assistant host often has little spare RAM and disk. Add packages and layers only when T3 Code or an agent really needs them. The Dockerfile uses `--no-install-recommends` and cleans apt lists; keep it that way. Startup must stay fast: the `HEALTHCHECK` allows 60 seconds, and the Supervisor restarts the add-on if it fails.

### 3. Remote ready

Pairing over the LAN or Tailscale must keep working. The server listens on `0.0.0.0:3773`, the log must show an address the user can actually use (not the container's internal one), and the pairing code must be printed on every start. If you touch networking, ports, the `announce` step or the output filter in `t3code/rootfs/etc/s6-overlay/s6-rc.d/t3/run`, check that flow end to end.

### 4. Safety of the user's Home Assistant config

Agents can break a running smart home. Never weaken the warnings in `README.md` and `DOCS.md`, never add a default that gives more access, never expose the port beyond what the user configured, and never log secrets. The ingress port 8099 accepts only the Supervisor (`172.30.32.2`) and loopback, the panel stays admin-only (`panel_admin` default), and the auto sign-in bearer lives only in a mode 600 file under `/run`. Telemetry stays off by default. Credentials (`anthropic_api_key`, `claude_code_oauth_token`) are `password` options and never appear in logs, docs examples or test fixtures.

## A note on principles

These are adapted from the upstream T3 Code `AGENTS.md`. Prefer ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists, and do not add machinery because it looks impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Honor the developer's intent in both a minimal and realistic fashion.

Think of these instructions less as hard rules and more as good defaults. The developer's preferences override anything here.

Most work on this repo happens from T3 Code itself, often controlled remotely, on a machine that runs a live T3 Code install. Be careful about accessing data, killing processes and anything else that could damage that instance.

## A small glossary

Use this language when communicating.

- **you** means the agent reading this file and changing this repo.
- **we, us, and maintainers** mean the people maintaining this add-on. These are who you are talking to now.
- **user** means the person running the add-on on their Home Assistant host and directing agents with T3 Code.
- **agent** means the coding agent a user runs inside T3 Code. Depending on context, that may also include you.
- **provider** means the agent runtime or harness T3 Code talks to. Here that is Claude Code.
- **client** means the T3 Code app (desktop, web or mobile) that pairs with the add-on.
- **environment** means one running T3 server and the machine, filesystem, credentials and state it owns. The add-on makes Home Assistant OS an environment.
- **project** means an environment-local workspace record rooted at a directory, such as `/homeassistant`.
- **thread** means the durable conversation and work history for a project.
- **T3 home** means T3 Code's base data directory. In the add-on it is `/data/t3`.
- **add-on** means the Home Assistant add-on built from `t3code/`. Home Assistant's UI may call it an "app".
- **Supervisor** means the Home Assistant component that installs, configures and runs add-ons. It writes `/data/options.json`.
- **upstream** means T3 Code (`pingdotgg/t3code`, npm `t3`) and Claude Code (npm `@anthropic-ai/claude-code`).

## The ways to hurt yourself

1. **Killing by pattern.** Never `pkill -f`, `pgrep | kill`, or `kill` a PID you found by matching a name or path. Your own agent process has this worktree's path in its argv, and this machine runs a live T3 Code server and possibly other containers. Kill only a PID you captured at spawn. Remove test containers by the exact name you gave them (`docker rm -f <name>`), never by filter.
2. **Touching the live install.** This dev machine usually runs a real T3 Code install: `~/.t3/userdata` is the developer's database and the service listens on `127.0.0.1:3773` (and on the LAN and Tailscale addresses). Reading is fine. Never write to it, stop the service, or bind port 3773 on the host. Test containers publish a random port (`-p 127.0.0.1::3773`, as `tests/smoke.sh` does).
3. **Baking in addresses.** Never put a host IP, hostname, tunnel address, pairing code or token into the image, scripts, translations or docs. Use `<your-HA-IP>` in examples. The server URL shown to users is derived at runtime from the Supervisor.
4. **Using the real Home Assistant config.** The user's `/homeassistant` is precious. Tests mount temp directories (`mktemp -d`) as `/data`, `/homeassistant` and `/share`. Never point a test container at a real config folder or at a real HA instance.

## Hit every surface

The most common defect is a change that works on the path you tested and is missing everywhere else. Before calling work done, walk this list and say which entries applied.

- **Options.** An option change touches all of: `t3code/config.yaml` (`options` and `schema`), `t3code/translations/en.yaml` **and** `de.yaml`, the `rootfs` script that reads it (via `opt` / `opt_list` from `lib.sh`), the Options section of `t3code/DOCS.md`, and `t3code/CHANGELOG.md`. A secret option is `password`, not `str`. Optional options end in `?` in the schema.
- **Versions.** The add-on version in `config.yaml` follows `scripts/check-upstream.sh`: a new T3 Code release `V` becomes `V`; a change that does not move T3 Code (Claude Code bump, add-on fix, option change) becomes `<T3 version>.<n>`, counting up (`0.0.45` -> `0.0.45.1` -> `0.0.45.2`) and resetting on the next T3 bump. `release.yaml` skips silently when tag `v<version>` already exists, so a change under `t3code/` that should ship needs a new version. Add a matching `## <version>` section to `t3code/CHANGELOG.md`; `scripts/changelog-section.sh` turns it into the release notes.
- **Pipeline.** `scripts/check-upstream.sh`, `scripts/read-config.sh`, `scripts/changelog-section.sh`, the three workflows, `tests/smoke.sh` and `tests/check-upstream.test.sh` agree on file names, keys and output formats. Change one, check the others. In particular the `image` field in `config.yaml` must match what `release.yaml` publishes, and `build.yaml` keys feed the Docker build args.
- **Dockerfile and rootfs.** `build.yaml` args (`T3_VERSION`, `CLAUDE_CODE_VERSION`) and the Dockerfile `ARG`s must match. New files under `rootfs/` need the right mode (scripts executable) and s6 wiring (`type`, `dependencies.d`, `user-bundles.d`).
- **Ingress panel.** `rootfs/etc/nginx/nginx.conf`, the `ingress` s6 service and `rootfs/usr/share/t3code/ingress/shim.js` make the T3 client work under `/api/hassio_ingress/<token>/`. The shim depends on T3 client internals (TanStack Router `basepath`, absolute URLs in HTML and CSS), so a T3 upgrade can break it silently. `tests/ingress-e2e.sh` is the guard: keep it green, and extend it when the panel gains behavior. Changes to the `ingress*` options, the port or the allow-list also touch `config.yaml`, translations, `DOCS.md`, the smoke test and the e2e supervisor emulation (`tests/ingress-e2e/supervisor.conf`).
- **Pairing flow.** The log output (server URL, pairing code, pairing link), `DOCS.md` and `README.md` describe the same flow. If the text printed by the `t3` service `run` script changes, update the docs and check `tests/smoke.sh` still matches.
- **Translations.** Every user-visible string in `translations/en.yaml` has a German twin in `de.yaml`, and the other way around.
- **Reverse states.** If you added a way in, add the way out. An option that switches something on needs a documented way to switch it off and a sensible default when unset. State in `/data` must survive a restart and an add-on update.
- **Connection modes.** LAN IP, `homeassistant.local`, Tailscale and plain `docker run` without a Supervisor all behave differently. The scripts must keep working when `SUPERVISOR_TOKEN` and `/data/options.json` are absent.
- **Docs.** Check whether the change makes existing guidance inaccurate. Apply the [documentation rules](#documentation) before adding anything.

## Commands

Requirements: Docker, `yq` v4, `jq`, `npm`; optionally `shellcheck`, `hadolint` and `actionlint`. Run from the repo root.

```bash
# Show what CI would build (versions, base image, build args)
scripts/read-config.sh

# Build the image like CI does (args come from t3code/build.yaml). Heavy: see Verifying.
docker build \
  --build-arg BUILD_FROM="$(yq '.build_from.amd64' t3code/build.yaml)" \
  --build-arg T3_VERSION="$(yq '.args.T3_VERSION' t3code/build.yaml)" \
  --build-arg CLAUDE_CODE_VERSION="$(yq '.args.CLAUDE_CODE_VERSION' t3code/build.yaml)" \
  -t local/t3code-amd64:dev t3code/

# Smoke test a built image (random host port, temp dirs, restart check)
tests/smoke.sh local/t3code-amd64:dev

# Browser test of the Ingress sidebar panel (Playwright, emulated Supervisor). Heavy: see Verifying.
tests/ingress-e2e.sh local/t3code-amd64:dev

# Offline unit test of the upstream update script (needs yq only)
tests/check-upstream.test.sh

# Shell lint, as in CI (uses local shellcheck, else the koalaman/shellcheck image)
scripts/lint-shell.sh

# Workflow lint
actionlint

# Dockerfile lint, as in CI
hadolint --failure-threshold warning t3code/Dockerfile

# Would an upstream update change anything? Touches no file.
scripts/check-upstream.sh --dry-run
```

CI also runs `frenck/action-app-linter` on `t3code/` (add-on config lint). There is no local equivalent in this repo.

## Verifying

- Smallest proof that the change works. For a script, run the script or its test. For an option, run the changed `rootfs` script logic with a temp `OPTIONS_FILE`. For docs, read them again.
- Pick the matching check: `tests/check-upstream.test.sh` for `check-upstream.sh`, `scripts/lint-shell.sh` for any shell file, `actionlint` for workflows, `hadolint` for the Dockerfile. Validate YAML you touched with `yq '.' <file>`.
- **Docker image builds are heavy.** The image is about 1 GB and the dev box has 4 GB of RAM. Ask before building or running the image locally. CI owns the full build, smoke test and ingress e2e test. The e2e test needs Playwright's Chromium and runs a headless browser; ask before running it locally.
- `tests/smoke.sh` publishes a random loopback port and uses temp dirs. Keep it that way; never make a test bind host port 3773.
- Local runs cannot reproduce the CI environment (`GITHUB_OUTPUT`, `GITHUB_TOKEN` permissions, `workflow_call` inputs, GHCR login). A new or changed workflow should be run once on a throwaway branch before it lands on `main`. `build-test.yaml` runs on pushes to any branch except `main`; `release.yaml` and the promote step deliberately do nothing off `main`. Delete the branch afterwards.
- Test meaningful behavior. Do not add tests that only mirror the implementation.
- Bash tests wait on a condition with a deadline (as `tests/smoke.sh` does), never on a fixed sleep.
- Don't verify with browsers or computer use unless the user explicitly agrees.

## Commits and pull requests

- Never open a PR unless the developer explicitly asks you to. Commit only when asked.
- Conventional commit titles, plain language: `fix(addon): pairing link shows the HA address`. Scopes in use: `addon`, `ci`, `docs`, `tests`, `scripts`. Dependabot uses `ci`; the auto-update bot uses `chore`.
- Body: the problem in a sentence or two, then how you fixed it. End with the model and harness that did the work.
- One request is one PR. Outside contributions follow the stricter [one problem per PR](CONTRIBUTING.md#one-problem) rule.
- Upload PR evidence (logs, screenshots) to GitHub. Never commit PR-only assets.
- `auto-update.yaml` pushes tested commits to `main` directly with `GITHUB_TOKEN` and opens issues labelled `auto-update-failed` when it fails. Do not add branch protection, required PR reviews or other rules that block that push without changing the workflow in the same change. Treat an open `auto-update-failed` issue as a signal, not noise.
- When babysitting a PR: poll checks and comments newer than the last push, verify each bot finding against the source, fix real ones, dismiss false positives with a written reason. Stop when checks are green on the latest commit.

## Documentation

Most changes do not need a documentation change. Agents can read the code.

- `t3code/DOCS.md` is the user guide shown in the add-on's Documentation tab. Write it in the product's voice for someone who runs Home Assistant, not for contributors. Cover tasks: install, pair, log in to Claude, options, paths, troubleshooting. Keep the options section in step with `config.yaml` and the translations.
- `README.md` is the repo overview for people who find it on GitHub: what it is, install, pairing, security notes, how updates work, development entry points.
- `t3code/CHANGELOG.md` records what changed for users, one `## <version>` section per release, newest first. The release notes are cut from it.
- Do not document every field or function, narrate control flow, maintain file catalogs, or append PR summaries. Scripts, config and tests already record the implementation.
- Explain a local implementation detail in a nearby code comment. Link to the source instead of copying it.
- When documented behavior changes, rewrite or remove the affected text. Do not append a second account of the new behavior.
- Keep real addresses, pairing codes and tokens out of docs. Use placeholders.

## Plans and work artifacts

- Do not commit implementation plans, research notes, or agent scratch files. Keep temporary working material outside the worktree (for example in `mktemp -d`).
- Track work in GitHub issues. A merged PR is the implementation record; do not keep a second checklist in the repository.

## Where things live

- `t3code/` - the add-on: `config.yaml`, `build.yaml`, `Dockerfile`, `npm-fetch.sh`, `DOCS.md`, `CHANGELOG.md`, `translations/`, icons.
- `t3code/rootfs/` - copied to `/` in the image. s6-overlay services `init-t3` (git defaults, project registration), `t3` (credentials, log level, pairing announcement, `t3 serve`) and `ingress` (auto sign-in bearer, then nginx on 8099). `usr/local/lib/t3code/lib.sh` holds the option helpers.
- `scripts/` - `check-upstream.sh` (npm version check and file update), `read-config.sh`, `changelog-section.sh`, `lint-shell.sh`.
- `tests/` - `smoke.sh` (container smoke test), `ingress-e2e.sh` with `ingress-e2e/` (Playwright test of the sidebar panel behind an emulated Supervisor), `check-upstream.test.sh` (offline test of the update script).
- `.github/workflows/` - `build-test.yaml`, `auto-update.yaml`, `release.yaml`.
- `repository.yaml`, `assets/` - repository metadata for the Home Assistant add-on store.

## Taste

- Scripts are bash and shellcheck-clean (`scripts/lint-shell.sh` uses `--severity=style`). Use `set -euo pipefail` in tools and tests. `rootfs` services use `set -uo pipefail` because a failing helper must not stop the add-on.
- Read options with `opt`, `opt_list` from `lib.sh`, not with ad-hoc `jq` calls. Options must also work without a Supervisor (`OPTIONS_FILE` override, defaults).
- Quote variables, prefer `[[ ]]`, and print errors to stderr.
- Keep the Dockerfile lint-clean under `hadolint --failure-threshold warning`. Justify any `# hadolint ignore=` with the reason.
- Pin what the pipeline manages (`build.yaml` args, base image tag). Do not hand-edit versions that `check-upstream.sh` owns, except through the version rules above.
- Comments describe how a thing is used, and move when the code moves. Use them mostly to describe functions and non-obvious constraints, not to annotate every line.
- Files and commit messages are in English. User-facing option text also exists in German.
- If a rule here fights the task in front of you, say so loudly and get a human sign-off before breaking it.

## Additional tips

- Security is important, but do not over-index on it for maintainer-only tooling. Do over-index on anything that handles credentials, ports or the user's config folder.
