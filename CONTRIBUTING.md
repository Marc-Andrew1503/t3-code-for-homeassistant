# Contributing

Thanks for helping. This is a small repo: a Home Assistant add-on that packages the
[T3 Code](https://github.com/pingdotgg/t3code) server and Claude Code. Review capacity is limited, and
opening a PR does not create an obligation to review or merge it. Meeting this guide makes a PR
eligible for review; it does not guarantee acceptance.

## Where things go

- **Bugs in the add-on** (startup, pairing, options, image, update pipeline, docs): open an
  [issue](https://github.com/Marc-Andrew1503/t3-code-for-homeassistant/issues/new/choose) with the bug form.
  Remove pairing codes, tokens and API keys from logs before pasting them.
- **Bugs in T3 Code itself** (the app, its UI, agents behaving oddly): report them upstream at
  [pingdotgg/t3code](https://github.com/pingdotgg/t3code/issues). This repo only packages it.
- **Ideas and feature requests**: open an issue with the feature form and describe the problem first.
  For larger changes, agree on direction before writing code.
- **Security problems**: follow the [security policy](.github/SECURITY.md). Do not open a public issue.

Search existing issues before opening a new one.

## Developer setup

Requirements: Docker, `yq` v4, `jq`, `npm`; optionally `shellcheck`, `hadolint` and `actionlint`.
The commands for building the image, running the smoke test, the shell lint and the script tests are
listed in [AGENTS.md](AGENTS.md#commands). Building the image takes about 1 GB and a few minutes; CI
runs the full build and smoke test for every PR.

<a id="one-problem"></a>

## Solve one underlying problem per PR

A PR that solves several independent problems should be split, even when each fix is useful. Count the
underlying problems, not the linked issues.

Include everything needed for that one problem: for example an option change touches `config.yaml`,
both translation files, the `rootfs` script, `DOCS.md` and `CHANGELOG.md`
(see [Hit every surface](AGENTS.md#hit-every-surface)). An adjacent cleanup or second fix needs its own PR.

Use a conventional commit title in plain language, such as `fix(addon): pairing link shows the HA address`.

Do not hand-edit what the update pipeline owns (the T3 Code and Claude Code versions in `build.yaml`)
unless that is the point of the PR. Version and changelog rules are in AGENTS.md.

<a id="verification"></a>

## Provide evidence for the changed behavior

Explain how you established the problem, how you checked the change, and what you observed. Give the
relevant reproduction steps, environment, the script, test or workflow run you used, and the result.
State what you could not check. "Tests pass" alone does not show that the change works.

Match the evidence to the change. A script fix needs the script or its test run. A change to the image,
the rootfs services or the workflows needs a CI run on your branch (`build-test.yaml` runs for PRs and
branch pushes). Do not substitute broad checks for checking the affected behavior. Attach or link
evidence in the PR; do not commit PR-only logs, screenshots or recordings.

Never include real IP addresses, pairing codes, tokens or API keys in a PR. Use `<your-HA-IP>`.

## Documentation

Follow the [documentation rules](AGENTS.md#documentation). `t3code/DOCS.md` is the user guide; update
it when how to use the add-on changes. Skip docs for internal changes the code already explains.

## Using agents

Agents are welcome. You are responsible for the result: read the diff, run the checks, and keep the PR
focused. Agents working here should read [AGENTS.md](AGENTS.md) first. End the PR description with the
model and harness that did the work.

PRs that miss these requirements may be closed with a note on what to fix. Correct the deficiency and
ask us to take another look.
