#!/usr/bin/env bash
# Smoke test for the T3 Code add-on image.
#
# Usage: tests/smoke.sh <image> [expected-t3-version]
#
# The expected T3 version defaults to args.T3_VERSION from t3code/build.yaml
# (needs yq) or the EXPECTED_T3_VERSION environment variable.
# Environment: READY_TIMEOUT (seconds to wait for HTTP 200, default 90),
#              CONTAINER_PORT (default 3773), DOCKER (docker command, default "docker").
set -euo pipefail

IMAGE="${1:?usage: tests/smoke.sh <image> [expected-t3-version]}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READY_TIMEOUT="${READY_TIMEOUT:-90}"
CONTAINER_PORT="${CONTAINER_PORT:-3773}"
DOCKER="${DOCKER:-docker}"

EXPECTED_T3_VERSION="${2:-${EXPECTED_T3_VERSION:-}}"
if [[ -z "${EXPECTED_T3_VERSION}" ]]; then
  EXPECTED_T3_VERSION="$(yq '.args.T3_VERSION' "${ROOT}/t3code/build.yaml")"
fi
[[ -n "${EXPECTED_T3_VERSION}" && "${EXPECTED_T3_VERSION}" != "null" ]] || {
  echo "cannot determine expected T3 version" >&2
  exit 2
}

NAME="t3code-smoke-$$-${RANDOM}"
WORKDIR="$(mktemp -d)"
RESULT=1
FAILURES=0

log() { echo "[smoke] $*"; }
pass() { echo "[smoke] PASS: $*"; }
fail() {
  echo "[smoke] FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

cleanup() {
  local status=$?
  set +e
  if [[ ${status} -ne 0 || ${RESULT} -ne 0 ]]; then
    echo "[smoke] ---- container state ----"
    ${DOCKER} ps -a --filter "name=${NAME}"
    echo "[smoke] ---- docker logs ----"
    ${DOCKER} logs "${NAME}" 2>&1 | tail -n 200
    echo "[smoke] ---- end of logs ----"
  fi
  ${DOCKER} rm -f "${NAME}" >/dev/null 2>&1
  # Files written by the (root) container may not be removable by us.
  rm -rf "${WORKDIR}" 2>/dev/null ||
    ${DOCKER} run --rm --entrypoint /bin/sh -v "${WORKDIR}:/cleanup" "${IMAGE}" -c 'rm -rf /cleanup/* /cleanup/.[!.]*' >/dev/null 2>&1
  rm -rf "${WORKDIR}" 2>/dev/null
  exit "${status}"
}
trap cleanup EXIT

die() {
  echo "[smoke] FATAL: $*" >&2
  exit 1
}

mkdir -p "${WORKDIR}/data" "${WORKDIR}/homeassistant" "${WORKDIR}/share"
chmod 777 "${WORKDIR}/data" "${WORKDIR}/homeassistant" "${WORKDIR}/share"
echo '{"log_level":"info"}' >"${WORKDIR}/data/options.json"

log "image=${IMAGE} expected T3 version=${EXPECTED_T3_VERSION}"
${DOCKER} run -d --name "${NAME}" \
  -p "127.0.0.1::${CONTAINER_PORT}" \
  -v "${WORKDIR}/data:/data" \
  -v "${WORKDIR}/homeassistant:/homeassistant" \
  -v "${WORKDIR}/share:/share" \
  "${IMAGE}" >/dev/null

is_running() {
  [[ "$(${DOCKER} inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null)" == "true" ]]
}

host_port() {
  ${DOCKER} port "${NAME}" "${CONTAINER_PORT}/tcp" | head -n1 | sed 's/.*://'
}

# http_code <path> -> prints the HTTP status code (000 on connection errors).
http_code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${PORT}$1" || true
}

# wait_ready: wait until GET / answers 200 or the container dies / timeout hits.
wait_ready() {
  local deadline=$((SECONDS + READY_TIMEOUT)) code
  PORT="$(host_port)"
  [[ -n "${PORT}" ]] || die "could not determine published host port"
  log "waiting up to ${READY_TIMEOUT}s for http://127.0.0.1:${PORT}/"
  while ((SECONDS < deadline)); do
    is_running || die "container exited while waiting for the web UI"
    code="$(http_code /)"
    if [[ "${code}" == "200" ]]; then
      return 0
    fi
    sleep 2
  done
  die "web UI did not return HTTP 200 within ${READY_TIMEOUT}s (last status: ${code:-none})"
}

wait_ready
pass "GET / returned 200 (host port ${PORT})"

BODY="$(curl -s --max-time 10 "http://127.0.0.1:${PORT}/")"
ASSET="$(printf '%s' "${BODY}" | grep -oE '/assets/[^"'"'"' )>]+\.js' | head -n1 || true)"
if [[ -n "${ASSET}" ]]; then
  pass "index.html references script ${ASSET}"
  code="$(http_code "${ASSET}")"
  if [[ "${code}" == "200" ]]; then
    pass "GET ${ASSET} returned 200"
  else
    fail "GET ${ASSET} returned ${code}"
  fi
else
  fail "index.html does not reference a /assets/*.js script"
fi

T3_OUT="$(${DOCKER} exec "${NAME}" t3 --version 2>&1 | tr -d '\r' | tail -n1 || true)"
# Output looks like "t3 v0.0.45"; compare the bare version number.
T3_VER="${T3_OUT##* }"
T3_VER="${T3_VER#v}"
if [[ "${T3_VER}" == "${EXPECTED_T3_VERSION}" ]]; then
  pass "t3 --version = ${T3_OUT}"
else
  fail "t3 --version is '${T3_OUT}', expected '${EXPECTED_T3_VERSION}'"
fi

if CLAUDE_OUT="$(${DOCKER} exec "${NAME}" claude --version 2>&1)"; then
  pass "claude --version = $(printf '%s' "${CLAUDE_OUT}" | tail -n1)"
else
  fail "claude --version failed: ${CLAUDE_OUT}"
fi

if is_running; then
  pass "container is still running"
else
  fail "container is not running"
fi

# Restart / persistence: state in /data must survive a container restart and
# the UI must come back up on its own.
${DOCKER} exec "${NAME}" sh -c 'echo persisted > /data/.smoke-marker' || fail "could not write marker to /data"
log "restarting container"
${DOCKER} restart "${NAME}" >/dev/null
wait_ready
pass "GET / returned 200 after restart"
if [[ "$(cat "${WORKDIR}/data/.smoke-marker" 2>/dev/null)" == "persisted" ]]; then
  pass "/data marker survived the restart"
else
  fail "/data marker missing after restart"
fi
if is_running; then
  pass "container still running after restart"
else
  fail "container not running after restart"
fi

if [[ ${FAILURES} -gt 0 ]]; then
  echo "[smoke] ${FAILURES} check(s) failed" >&2
  exit 1
fi
RESULT=0
log "all checks passed"
