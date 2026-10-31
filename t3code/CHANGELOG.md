# Changelog

## 0.1.6

- Update T3 Code to 0.1.6 ([release notes](https://github.com/pingdotgg/t3code/releases))

## 0.1.5.2

- Update Claude Code to 2.1.316 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.5.1

- Update Claude Code to 2.1.314 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.5

- Update T3 Code to 0.1.5 ([release notes](https://github.com/pingdotgg/t3code/releases))

## 0.1.4

- Update T3 Code to 0.1.4 ([release notes](https://github.com/pingdotgg/t3code/releases))

## 0.1.3.1

- Update Claude Code to 2.1.312 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.3

- Update T3 Code to 0.1.3 ([release notes](https://github.com/pingdotgg/t3code/releases))

## 0.1.2.2

- Update Claude Code to 2.1.311 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.2.1

- Update Claude Code to 2.1.310 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.2

- Update T3 Code to 0.1.2 ([release notes](https://github.com/pingdotgg/t3code/releases))
- Update Claude Code to 2.1.309 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.0.5

- Update Claude Code to 2.1.305 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.0.4

- Update Claude Code to 2.1.304 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.0.3

- Update Claude Code to 2.1.303 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.0.2

- Update Claude Code to 2.1.302 ([changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md))

## 0.1.0.1

- New "T3 Code" panel in the Home Assistant sidebar (Ingress). It works through any way you reach Home Assistant, including remote HTTPS access such as Nabu Casa, is limited to administrators and signs you in automatically.
- New option `ingress_auto_login` (default on). Turn it off to pair manually inside the panel.
- Direct access on port 3773 and pairing with the T3 Code app work as before.

## 0.1.0

- Update T3 Code to 0.1.0 ([release notes](https://github.com/pingdotgg/t3code/releases))

## 0.0.45.2

- Grant Supervisor API access so the add-on log shows the real Home Assistant address and port instead of `<your-HA-IP>`.

## 0.0.45.1

- Replace the obsolete `watchdog` option with a Docker `HEALTHCHECK`.
- Drop `startup`/`boot` keys that only repeated the defaults.

## 0.0.45

- Initial release of the T3 Code add-on.
- Bundles T3 Code 0.0.45 and Claude Code 2.1.301 (amd64 only).
- Pairing code and server URL are printed in the add-on log on every start.
- Your Home Assistant configuration (`/homeassistant`) is registered as a T3 project automatically.
- Optional `anthropic_api_key` / `claude_code_oauth_token` options for Claude Code authentication.
