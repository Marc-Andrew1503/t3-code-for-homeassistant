# T3 Code

This add-on runs the [T3 Code](https://github.com/pingdotgg/t3code) server inside
Home Assistant, together with the [Claude Code](https://claude.com/claude-code) CLI.
You connect your T3 Code desktop or web client to it as a *remote environment* and
let Claude Code agents work on your Home Assistant configuration
(`/homeassistant`, i.e. the folder that contains `configuration.yaml`).

> **Warning - agents can change your Home Assistant configuration.**
> The add-on has read/write access to your config folder and to `/share`, and an
> agent can run arbitrary shell commands inside the add-on container (that is the
> point). A bad edit can stop Home Assistant from starting. **Create a backup
> before you start**, review what agents do (especially in T3's "Full access"
> mode), and never expose port 3773 to the internet. Everyone who can open the
> **T3 Code** sidebar panel (Home Assistant administrators) has the same power.

## Installation

1. Add this repository to the Home Assistant app/add-on store and install **T3 Code**.
2. (Optional) Review the options below, e.g. add your Claude credentials.
3. Start the add-on. Open the **T3 Code** panel in the Home Assistant sidebar
   (or **Open Web UI** on the add-on page), or pair the T3 Code app as described
   below.

## Sidebar panel

The **T3 Code** entry in the Home Assistant sidebar shows the T3 Code web UI
inside Home Assistant (Ingress). It works wherever you can reach Home Assistant,
including remote HTTPS access such as Nabu Casa or Cloudflare, without opening
port 3773. Only Home Assistant administrators see it, and it signs you in
automatically, so no pairing code is needed. If you prefer to pair manually in
the panel, turn off `ingress_auto_login`.

To use the T3 Code desktop or mobile app instead, pair it directly (next
section). Signing in with T3 Connect works only on t3.codes, not inside the panel.

## First start and pairing

T3 Code uses one-time pairing codes. On every start the add-on log shows a box like
this:

```
==============================================================================
 T3 Code is ready. Pair your T3 Code desktop/web client with this server.

   Server URL : http://<your-HA-IP>:3773
   (or        : http://homeassistant.local:3773)
   Pairing code (valid 1 hour, single use): <pairing-code>
   Pairing link: http://<your-HA-IP>:3773/pair#token=<pairing-code>
...
```

To pair:

1. Open the T3 Code desktop app (or any T3 Code web client).
2. Go to **Settings -> Connections -> Add environment**.
3. Enter the **server URL** from the log and the **pairing code**. Alternatively,
   open the pairing link directly in the client.
4. The Home Assistant environment now appears in your client. Its projects are
   listed there, and `Home Assistant config` is already registered.

Notes:

- **Direct connection only.** Use `http://<HA-IP>:3773`, `http://homeassistant.local:3773`
  or the Tailscale IP / MagicDNS name of your Home Assistant host if you use
  Tailscale. The address T3 itself prints (the container's internal address) is
  not reachable from outside; the add-on rewrites it to the correct one when it
  can read it from the Supervisor. If the log shows `<your-HA-IP>`, replace it
  with the IP address of your Home Assistant host.
- The connection is plain HTTP on your local network. Do not forward port 3773 on
  your router. For remote access use a VPN such as Tailscale or WireGuard.
- T3 also prints its own startup block (`Pairing code (admin, valid 5 minutes)`).
  That code has administrator rights (it lets the paired client create further
  pairing codes and manage connected devices) but expires after 5 minutes. The
  1 hour code has the normal client permissions, which is enough for working with
  agents.
- **Need a new code?** Codes are single use and expire. Simply restart the add-on;
  a fresh code is printed on every start. Your data, projects and paired clients
  are kept across restarts. Already paired clients stay paired.
- You can revoke paired clients in T3 under **Settings -> Connections**.

## Claude Code login

T3 starts the `claude` CLI that is installed in the add-on. It needs to be
authenticated. Pick one of these ways:

1. **Subscription token (recommended for Claude Pro/Max).** On any computer where
   Claude Code is installed, run `claude setup-token` and paste the resulting
   token into the `claude_code_oauth_token` option.
2. **Anthropic API key.** Paste an API key into the `anthropic_api_key` option
   (billed per use).
3. **Interactive login.** Open a terminal inside T3 Code (in the Home Assistant
   environment) and run `claude auth login`, then follow the instructions. The
   login is stored in `/data/home/.claude` and persists across restarts and
   updates.

T3's provider status may show Claude as ready even when you are not logged in
yet; if agent turns fail with "Not logged in", use one of the methods above.

Claude Code's built-in auto-updater is disabled. New Claude Code versions are
delivered through add-on updates.

## Data and paths

| Path | Purpose |
| --- | --- |
| `/homeassistant` | Your Home Assistant configuration (read/write) |
| `/share` | The Home Assistant `share` folder (read/write) |
| `/data/t3` | T3 Code state (database, pairing, settings, worktrees); persistent |
| `/data/home` | Home directory of the agent environment (`~/.claude` login, `~/.gitconfig`, `~/.ssh` keys); persistent |

`/data` is included in Home Assistant backups of this add-on. It contains your
Claude login and T3 secrets, so treat backups accordingly.

The Home Assistant config folder is not a git repository by default. If you want
agents (and T3's diff/review features) to track changes, run `git init` in it from
a T3 terminal and add a `.gitignore` for `secrets.yaml`, `.storage/`, `*.db*` and
`*.log*`.

## Options

| Option | Default | Description |
| --- | --- | --- |
| `log_level` | `info` | Verbosity of the T3 server log: `trace`, `debug`, `info`, `warn` or `error`. |
| `projects` | `["/homeassistant"]` | Folders registered as T3 projects at every start. Missing folders are skipped with a warning. Projects are never removed automatically; remove them in the T3 UI. |
| `git_user_name` | _(empty)_ | Git author name for commits made by agents. Defaults to `T3 Code`. |
| `git_user_email` | _(empty)_ | Git author email for commits made by agents. Defaults to `t3code@homeassistant.local`. |
| `anthropic_api_key` | _(empty)_ | Exported as `ANTHROPIC_API_KEY` for Claude Code. |
| `claude_code_oauth_token` | _(empty)_ | Exported as `CLAUDE_CODE_OAUTH_TOKEN` for Claude Code. |
| `telemetry` | `false` | Allow T3 Code's anonymous usage analytics. Off by default. |
| `ingress_auto_login` | `true` | Sign in automatically in the sidebar panel. Turn off to pair manually there. |

Example:

```yaml
log_level: info
projects:
  - /homeassistant
  - /share
git_user_name: Jane Doe
git_user_email: jane@example.com
```

## Network

| Port | Description |
| --- | --- |
| `3773/tcp` | T3 Code server (web UI, pairing and client connections) |

The sidebar panel does not use this port; Home Assistant reaches the add-on on
its internal network.

You can change the host port in the add-on's **Network** section; the log then
shows the mapped port.

## Troubleshooting

- **The sidebar panel asks to pair or shows an error:** restart the add-on and
  reload the page. If it still asks to pair, pair as described above or check
  that `ingress_auto_login` is on. Only administrators see the panel.
- **Add-on log shows no pairing code:** restart the add-on and check the log
  again; the box is printed after the server has started (a few seconds).
- **"Pairing failed" in the client:** the code was already used or expired.
  Restart the add-on and use the new code.
- **Cannot connect from the client:** check that the client can reach
  `http://<HA-IP>:3773` in a browser. Firewalls, VLANs or a VPN may block it.
- **Claude says "Not logged in":** see [Claude Code login](#claude-code-login).
- **`--dangerously-skip-permissions` / "Full access" mode:** the add-on sets
  `IS_SANDBOX=1` so that Claude Code allows this mode while running as root in the
  container. Be aware that agents then act without confirmations.

## Support

Issues and questions about the add-on: see the repository linked on the add-on
page. T3 Code itself: <https://github.com/pingdotgg/t3code>.
