#!/usr/bin/env bash
# Run shellcheck over all shell scripts of the repository: scripts/, tests/ and
# t3code/*.sh and everything shell-like below t3code/rootfs (executables, *.sh, or files with a
# shell/bashio shebang).
#
# Uses the local `shellcheck` if available, otherwise falls back to the
# koalaman/shellcheck Docker image (set DOCKER="sudo docker" if needed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

files=()
while IFS= read -r -d '' f; do
  case "${f}" in
    *.sh | *.bash) files+=("${f}") ;;
    *)
      if [[ -x "${f}" ]] || head -n1 "${f}" | grep -Eq '^#!.*(sh|bash|bashio)\b'; then
        files+=("${f}")
      fi
      ;;
  esac
done < <(
  {
    find scripts tests t3code/rootfs -type f -not -name '*.md' -not -name '*.json' -not -name '*.yaml' -not -name '*.yml' -print0 2>/dev/null
    find t3code -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null
  } | sort -z
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "no shell files found"
  exit 0
fi

# SC1091: bashio and other sourced files only exist inside the add-on image.
# -s bash: files with an unknown shebang (e.g. #!/usr/bin/with-contenv bashio) are treated as bash.
args=(-s bash -e SC1091 --severity=style)

printf 'shellcheck: %s\n' "${files[@]}"
if command -v shellcheck >/dev/null; then
  shellcheck "${args[@]}" "${files[@]}"
else
  # shellcheck disable=SC2086
  ${DOCKER:-docker} run --rm -v "${ROOT}:/mnt" -w /mnt koalaman/shellcheck:stable "${args[@]}" "${files[@]}"
fi
echo "shellcheck: OK"
