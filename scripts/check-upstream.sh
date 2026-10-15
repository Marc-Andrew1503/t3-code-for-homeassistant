#!/usr/bin/env bash
# Check npm for new stable releases of T3 Code (`t3`) and Claude Code
# (`@anthropic-ai/claude-code`) and update the add-on files accordingly.
#
# Usage: scripts/check-upstream.sh [--dry-run] [--dir <addon-dir>]
#
#   --dry-run      Report what would change, but do not modify any file.
#   --dir <dir>    Add-on directory (default: <repo>/t3code).
#
# Environment (mainly for tests):
#   T3_LATEST, CLAUDE_CODE_LATEST   Skip npm and use these as "latest" versions.
#   GITHUB_OUTPUT                   If set, results are appended there, else printed.
#
# Versioning scheme:
#   * New T3 version V           -> add-on version V (e.g. 0.0.46)
#   * Only Claude Code changed   -> add-on version <T3>.<n> (0.0.45 -> 0.0.45.1 -> 0.0.45.2)
#                                   The counter resets with the next T3 bump.
#
# Outputs: changed=true|false, version=<add-on version>, summary=<one line>,
#          previous_version, t3_version, claude_version
#
# The script is idempotent: running it again after an update reports changed=false.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_DIR="${ROOT}/t3code"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --dir)
      ADDON_DIR="${2:?--dir needs a value}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,24p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

CONFIG="${ADDON_DIR}/config.yaml"
BUILD="${ADDON_DIR}/build.yaml"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"

T3_RELEASES_URL="https://github.com/pingdotgg/t3code/releases"
CLAUDE_CHANGELOG_URL="https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md"
STABLE_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

log() { echo "check-upstream: $*" >&2; }
die() {
  log "ERROR: $*"
  exit 1
}

for tool in yq jq; do
  command -v "${tool}" >/dev/null || die "${tool} is required"
done
[[ -f "${CONFIG}" ]] || die "missing ${CONFIG}"
[[ -f "${BUILD}" ]] || die "missing ${BUILD}"

# Succeeds if $1 is strictly newer than $2 (version sort).
version_gt() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

# npm_latest <package> -> stable "latest" dist-tag, with retries.
npm_latest() {
  local pkg="$1" out="" attempt
  command -v npm >/dev/null || die "npm is required"
  for attempt in 1 2 3; do
    if out="$(npm view "${pkg}" dist-tags.latest 2>/dev/null)" && [[ -n "${out}" ]]; then
      printf '%s\n' "${out}"
      return 0
    fi
    log "npm view ${pkg} failed (attempt ${attempt}/3)"
    sleep $((attempt * 3))
  done
  return 1
}

cur_t3="$(yq '.args.T3_VERSION' "${BUILD}")"
cur_claude="$(yq '.args.CLAUDE_CODE_VERSION' "${BUILD}")"
cur_addon="$(yq '.version' "${CONFIG}")"
for v in "${cur_t3}" "${cur_claude}" "${cur_addon}"; do
  [[ -n "${v}" && "${v}" != "null" ]] || die "could not read current versions from ${ADDON_DIR}"
done
log "current: t3=${cur_t3} claude-code=${cur_claude} add-on=${cur_addon}"

latest_t3="${T3_LATEST:-}"
latest_claude="${CLAUDE_CODE_LATEST:-}"
[[ -n "${latest_t3}" ]] || latest_t3="$(npm_latest t3)" || die "cannot query npm for t3"
[[ -n "${latest_claude}" ]] || latest_claude="$(npm_latest @anthropic-ai/claude-code)" || die "cannot query npm for @anthropic-ai/claude-code"
log "npm latest: t3=${latest_t3} claude-code=${latest_claude}"

# Only ever move forward and only to stable x.y.z versions.
new_t3="${cur_t3}"
if [[ ! "${latest_t3}" =~ ${STABLE_RE} ]]; then
  log "ignoring non-stable t3 version '${latest_t3}'"
elif version_gt "${latest_t3}" "${cur_t3}"; then
  new_t3="${latest_t3}"
fi

new_claude="${cur_claude}"
if [[ ! "${latest_claude}" =~ ${STABLE_RE} ]]; then
  log "ignoring non-stable claude-code version '${latest_claude}'"
elif version_gt "${latest_claude}" "${cur_claude}"; then
  new_claude="${latest_claude}"
fi

t3_changed=false
claude_changed=false
[[ "${new_t3}" != "${cur_t3}" ]] && t3_changed=true
[[ "${new_claude}" != "${cur_claude}" ]] && claude_changed=true

new_addon="${cur_addon}"
if [[ "${t3_changed}" == true ]]; then
  new_addon="${new_t3}"
elif [[ "${claude_changed}" == true ]]; then
  base="${cur_t3}"
  base_re="${base//./\\.}"
  if [[ "${cur_addon}" =~ ^${base_re}\.([0-9]+)$ ]]; then
    new_addon="${base}.$((BASH_REMATCH[1] + 1))"
  else
    new_addon="${base}.1"
  fi
fi

changed=false
parts=()
if [[ "${t3_changed}" == true || "${claude_changed}" == true ]]; then
  changed=true
  [[ "${t3_changed}" == true ]] && parts+=("T3 Code ${cur_t3} -> ${new_t3}")
  [[ "${claude_changed}" == true ]] && parts+=("Claude Code ${cur_claude} -> ${new_claude}")
fi

summary="No upstream changes"
if [[ "${changed}" == true ]]; then
  summary="Update $(printf '%s, ' "${parts[@]}")"
  summary="${summary%, } (add-on ${cur_addon} -> ${new_addon})"
fi

if [[ "${changed}" == true ]]; then
  log "${summary}"
  if [[ "${DRY_RUN}" == true ]]; then
    log "--dry-run: not modifying any files"
  else
    # Build the changelog entry.
    entry="## ${new_addon}
"
    if [[ "${t3_changed}" == true ]]; then
      entry+="
- Update T3 Code to ${new_t3} ([release notes](${T3_RELEASES_URL}))"
    fi
    if [[ "${claude_changed}" == true ]]; then
      entry+="
- Update Claude Code to ${new_claude} ([changelog](${CLAUDE_CHANGELOG_URL}))"
    fi
    entry+="
"

    # Skip the changelog if this version already has a heading (idempotency).
    if [[ -f "${CHANGELOG}" ]] && grep -Eq "^##[[:space:]]+\[?${new_addon//./\\.}\]?([[:space:]]|\$)" "${CHANGELOG}"; then
      log "CHANGELOG already has an entry for ${new_addon}; leaving it unchanged"
    else
      tmp="$(mktemp)"
      if [[ -f "${CHANGELOG}" ]] && grep -q '^## ' "${CHANGELOG}"; then
        ENTRY="${entry}" awk '
          !done && /^## / { print ENVIRON["ENTRY"]; done = 1 }
          { print }
        ' "${CHANGELOG}" >"${tmp}"
      else
        {
          if [[ -f "${CHANGELOG}" ]]; then cat "${CHANGELOG}"; else echo "# Changelog"; fi
          echo
          printf '%s' "${entry}"
        } >"${tmp}"
      fi
      cat "${tmp}" >"${CHANGELOG}"
      rm -f "${tmp}"
    fi

    NEW_T3="${new_t3}" NEW_CLAUDE="${new_claude}" NEW_ADDON="${new_addon}" yq -i '
      .args.T3_VERSION = strenv(NEW_T3) | .args.T3_VERSION style = "double" |
      .args.CLAUDE_CODE_VERSION = strenv(NEW_CLAUDE) | .args.CLAUDE_CODE_VERSION style = "double"
    ' "${BUILD}"
    NEW_ADDON="${new_addon}" yq -i '.version = strenv(NEW_ADDON) | .version style = "double"' "${CONFIG}"
  fi
else
  log "${summary}"
fi

emit() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1" >>"${GITHUB_OUTPUT}"
  else
    echo "$1"
  fi
}

emit "changed=${changed}"
emit "version=${new_addon}"
emit "summary=${summary}"
emit "previous_version=${cur_addon}"
emit "t3_version=${new_t3}"
emit "claude_version=${new_claude}"
