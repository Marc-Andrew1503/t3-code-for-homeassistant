# Changelog

## 0.0.45.1

- Replace the obsolete `watchdog` option with a Docker `HEALTHCHECK`.
- Drop `startup`/`boot` keys that only repeated the defaults.

## 0.0.45

- Initial release of the T3 Code add-on.
- Bundles T3 Code 0.0.45 and Claude Code 2.1.301 (amd64 only).
- Pairing code and server URL are printed in the add-on log on every start.
- Your Home Assistant configuration (`/homeassistant`) is registered as a T3 project automatically.
- Optional `anthropic_api_key` / `claude_code_oauth_token` options for Claude Code authentication.
