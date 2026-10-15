#!/usr/bin/env bash
# Print the body of the "## <version>" section of a Markdown changelog.
#
# Usage: scripts/changelog-section.sh <version> [changelog-file]
# Default file: t3code/CHANGELOG.md. Falls back to a generic line if the
# section is missing or empty so release creation never fails on notes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?usage: changelog-section.sh <version> [file]}"
FILE="${2:-${ROOT}/t3code/CHANGELOG.md}"

section=""
if [[ -f "${FILE}" ]]; then
  section="$(
    awk -v v="${VERSION}" '
      /^##[[:space:]]/ {
        if (found) exit
        title = $0
        sub(/^##[[:space:]]+/, "", title)
        sub(/[[:space:]]+.*$/, "", title)
        gsub(/^\[|\]$/, "", title)
        if (title == v) { found = 1; next }
      }
      found { print }
    ' "${FILE}"
  )"
fi

# Trim leading/trailing blank lines.
section="$(printf '%s\n' "${section}" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ -z "${section//[$'\n\r\t ']/}" ]]; then
  section="Release ${VERSION}."
fi
printf '%s\n' "${section}"
