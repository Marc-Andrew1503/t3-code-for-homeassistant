#!/usr/bin/env bash
# Browser test of the Home Assistant Ingress sidebar panel.
#
# Usage: tests/ingress-e2e.sh <image>
#
# Starts the add-on image with temp dirs, puts an nginx container that emulates
# the Supervisor's ingress proxy in front of it (sharing the add-on's network
# namespace, so the add-on's allow-list sees 127.0.0.1) and drives the panel
# with Playwright (tests/ingress-e2e/e2e.mjs). Publishes only a random loopback
# host port, never 3773.
#
# Needs node + npm. The first run installs the pinned Playwright package; the
# browser comes from `npx playwright install chromium-headless-shell` (or an
# existing PLAYWRIGHT_BROWSERS_PATH).
# Environment: READY_TIMEOUT (seconds to wait for the panel, default 120),
#              E2E_SCREENSHOT_DIR (write failure screenshots there),
#              SUPERVISOR_IMAGE (default nginx:alpine), DOCKER (default "docker").
set -euo pipefail

IMAGE="${1:?usage: tests/ingress-e2e.sh <image>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E_DIR="${ROOT}/tests/ingress-e2e"
READY_TIMEOUT="${READY_TIMEOUT:-120}"
SUPERVISOR_IMAGE="${SUPERVISOR_IMAGE:-nginx:alpine}"
DOCKER="${DOCKER:-docker}"
TOKEN="e2etoken"
OUTER_PORT=18123

ADDON="t3code-e2e-$$-${RANDOM}"
SUPERVISOR="${ADDON}-supervisor"
WORKDIR="$(mktemp -d)"

log() { echo "[e2e] $*"; }

cleanup() {
  local status=$?
  set +e
  if [[ ${status} -ne 0 ]]; then
    echo "[e2e] ---- add-on log ----"
    ${DOCKER} logs "${ADDON}" 2>&1 | tail -n 100
    echo "[e2e] ---- supervisor emulation log ----"
    ${DOCKER} logs "${SUPERVISOR}" 2>&1 | tail -n 100
    echo "[e2e] ---- end of logs ----"
  fi
  ${DOCKER} rm -f "${SUPERVISOR}" >/dev/null 2>&1
  ${DOCKER} rm -f "${ADDON}" >/dev/null 2>&1
  # Files written by the (root) container may not be removable by us.
  rm -rf "${WORKDIR}" 2>/dev/null ||
    ${DOCKER} run --rm --entrypoint /bin/sh -v "${WORKDIR}:/cleanup" "${IMAGE}" -c 'rm -rf /cleanup/* /cleanup/.[!.]*' >/dev/null 2>&1
  rm -rf "${WORKDIR}" 2>/dev/null
  exit "${status}"
}
trap cleanup EXIT

die() {
  echo "[e2e] FATAL: $*" >&2
  exit 1
}

mkdir -p "${WORKDIR}/data" "${WORKDIR}/homeassistant" "${WORKDIR}/share"
chmod 777 "${WORKDIR}/data" "${WORKDIR}/homeassistant" "${WORKDIR}/share"
# The Supervisor always writes the option defaults; mirror the ones the test relies on.
echo '{"log_level":"info","projects":["/homeassistant"]}' >"${WORKDIR}/data/options.json"

log "starting add-on image ${IMAGE}"
${DOCKER} run -d --name "${ADDON}" \
  -p "127.0.0.1::${OUTER_PORT}" \
  -v "${WORKDIR}/data:/data" \
  -v "${WORKDIR}/homeassistant:/homeassistant" \
  -v "${WORKDIR}/share:/share" \
  "${IMAGE}" >/dev/null

${DOCKER} run -d --name "${SUPERVISOR}" \
  --network "container:${ADDON}" \
  -v "${E2E_DIR}/supervisor.conf:/etc/nginx/nginx.conf:ro" \
  "${SUPERVISOR_IMAGE}" >/dev/null

PORT="$(${DOCKER} port "${ADDON}" "${OUTER_PORT}/tcp" | head -n1 | sed 's/.*://')"
[[ -n "${PORT}" ]] || die "could not determine the published host port"
BASE="http://127.0.0.1:${PORT}"
ENTRY="${BASE}/api/hassio_ingress/${TOKEN}/"

# Wait for the ingress index (the ingress service starts after T3 is ready).
log "waiting up to ${READY_TIMEOUT}s for ${ENTRY}"
deadline=$((SECONDS + READY_TIMEOUT))
code=""
while ((SECONDS < deadline)); do
  [[ "$(${DOCKER} inspect -f '{{.State.Running}}' "${ADDON}" 2>/dev/null)" == "true" ]] ||
    die "add-on container exited while waiting for the panel"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${ENTRY}" || true)"
  [[ "${code}" == "200" ]] && break
  sleep 2
done
[[ "${code}" == "200" ]] || die "the panel did not return HTTP 200 within ${READY_TIMEOUT}s (last status: ${code:-none})"

# Anything outside the ingress prefix must be blocked by the Supervisor emulation.
[[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${BASE}/e2e-root-probe")" == "404" ]] ||
  die "the Supervisor emulation does not answer 404 at its root"

cd "${E2E_DIR}"
if [[ ! -d node_modules ]]; then
  log "installing Playwright"
  npm ci --no-audit --no-fund
fi
log "running the browser test"
node e2e.mjs "${BASE}" "${TOKEN}"

# The browser test sees HTTP; the proxy log also covers WebSockets and workers.
# Log lines look like "<status> <method> <uri>"; only the ingress prefix is allowed.
leaks="$(${DOCKER} logs "${SUPERVISOR}" 2>&1 |
  grep -E '^[0-9]{3} [A-Z]+ /' |
  grep -vE " /api/hassio_ingress/${TOKEN}/" |
  grep -vF ' /e2e-root-probe' || true)" # the wrapper's own probe of the root
if [[ -n "${leaks}" ]]; then
  echo "[e2e] requests escaped the ingress prefix:" >&2
  echo "${leaks}" >&2
  exit 1
fi
log "no request escaped the ingress prefix"
log "all checks passed"
