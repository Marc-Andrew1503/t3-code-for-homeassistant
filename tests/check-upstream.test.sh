#!/usr/bin/env bash
# Offline tests for scripts/check-upstream.sh, using a throw-away add-on fixture.
# Usage: tests/check-upstream.test.sh   (needs yq v4)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/check-upstream.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
ADDON="${TMP}/t3code"
failures=0

reset_fixture() {
  rm -rf "${ADDON}"
  mkdir -p "${ADDON}"
  cat >"${ADDON}/config.yaml" <<'YAML'
name: "T3 Code"
version: "0.0.45" # managed by CI
slug: t3code
image: "ghcr.io/marc-andrew1503/t3code-{arch}"
YAML
  cat >"${ADDON}/build.yaml" <<'YAML'
build_from:
  amd64: debian:trixie-slim
args:
  T3_VERSION: "0.0.45"
  CLAUDE_CODE_VERSION: "2.1.300"
YAML
  printf '# Changelog\n\n## 0.0.45\n\n- Initial release\n' >"${ADDON}/CHANGELOG.md"
}

# run <t3-latest> <claude-latest> [extra args] -> output in ${OUT}
run() {
  OUT="$(T3_LATEST="$1" CLAUDE_CODE_LATEST="$2" "${SCRIPT}" --dir "${ADDON}" "${@:3}" 2>/dev/null)"
}

expect() { # expect <description> <actual> <expected>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (got '$2', expected '$3')" >&2
    failures=$((failures + 1))
  fi
}

out_val() { grep "^$1=" <<<"${OUT}" | head -n1 | cut -d= -f2-; }

reset_fixture
run 0.0.45 2.1.300
expect "no change: changed=false" "$(out_val changed)" false
expect "no change: version kept" "$(out_val version)" 0.0.45

run 0.0.46 2.1.301 --dry-run
expect "dry-run reports change" "$(out_val changed)" true
expect "dry-run leaves version untouched" "$(yq '.version' "${ADDON}/config.yaml")" 0.0.45

run 0.0.45 2.1.301
expect "claude-only: changed" "$(out_val changed)" true
expect "claude-only: version 0.0.45.1" "$(out_val version)" 0.0.45.1
expect "claude-only: config version" "$(yq '.version' "${ADDON}/config.yaml")" 0.0.45.1
expect "claude-only: build.yaml claude" "$(yq '.args.CLAUDE_CODE_VERSION' "${ADDON}/build.yaml")" 2.1.301
expect "claude-only: build.yaml t3 untouched" "$(yq '.args.T3_VERSION' "${ADDON}/build.yaml")" 0.0.45
expect "config.yaml comment preserved" "$(grep -c 'managed by CI' "${ADDON}/config.yaml")" 1

run 0.0.45 2.1.301
expect "idempotent: second run changed=false" "$(out_val changed)" false

run 0.0.45 2.1.302
expect "claude-only again: version 0.0.45.2" "$(out_val version)" 0.0.45.2

run 0.0.46 2.1.302
expect "t3 bump resets counter" "$(out_val version)" 0.0.46
expect "changelog newest entry on top" "$(grep -m1 '^## ' "${ADDON}/CHANGELOG.md")" "## 0.0.46"
expect "changelog keeps old entries" "$(grep -c '^## ' "${ADDON}/CHANGELOG.md")" 4

run 0.0.47-beta.1 2.1.302
expect "prerelease ignored" "$(out_val changed)" false

run 0.0.1 2.0.0
expect "older versions ignored" "$(out_val changed)" false

run 0.0.100 2.1.302
expect "version sort is numeric (0.0.100 > 0.0.46)" "$(out_val changed)" true

[[ ${failures} -eq 0 ]] || {
  echo "${failures} test(s) failed" >&2
  exit 1
}
echo "all check-upstream tests passed"
