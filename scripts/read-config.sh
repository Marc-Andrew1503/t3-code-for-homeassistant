#!/usr/bin/env bash
# Read the add-on build configuration (config.yaml + build.yaml) and emit it as
# key=value lines to $GITHUB_OUTPUT (or stdout when unset).
#
# Usage: scripts/read-config.sh [--dir <addon-dir>]
#
# Keys: version, t3_version, claude_version, build_from, image, build_args
# (build_args is a multi-line value: BUILD_FROM plus every entry of build.yaml args).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_DIR="${ROOT}/t3code"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      ADDON_DIR="${2:?--dir needs a value}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,9p' "${BASH_SOURCE[0]}"
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
for f in "${CONFIG}" "${BUILD}"; do
  [[ -f "${f}" ]] || {
    echo "missing file: ${f}" >&2
    exit 1
  }
done

version="$(yq '.version' "${CONFIG}")"
image="$(yq '.image // ""' "${CONFIG}")"
t3_version="$(yq '.args.T3_VERSION' "${BUILD}")"
claude_version="$(yq '.args.CLAUDE_CODE_VERSION' "${BUILD}")"
build_from="$(yq '.build_from.amd64' "${BUILD}")"
build_args="BUILD_FROM=${build_from}
$(yq '.args | to_entries | .[] | .key + "=" + (.value | tostring)' "${BUILD}")"

for pair in "version=${version}" "t3_version=${t3_version}" "claude_version=${claude_version}" "build_from=${build_from}"; do
  case "${pair#*=}" in
    '' | null)
      echo "could not read ${pair%%=*}" >&2
      exit 1
      ;;
  esac
done

emit() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1" >>"${GITHUB_OUTPUT}"
  else
    echo "$1"
  fi
}

emit "version=${version}"
emit "image=${image}"
emit "t3_version=${t3_version}"
emit "claude_version=${claude_version}"
emit "build_from=${build_from}"
emit "build_args<<BUILD_ARGS_EOF
${build_args}
BUILD_ARGS_EOF"
