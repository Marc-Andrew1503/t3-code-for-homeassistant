# shellcheck shell=bash
# Shared helpers for the T3 Code add-on services.
#
# Options are read straight from the options file the Supervisor writes to
# /data/options.json, so the scripts also work when no Supervisor API is
# reachable (e.g. when the image is started with plain `docker run`).

OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"

# opt <key> [default]  -> prints the scalar option value, or the default.
opt() {
    local value=""
    if [[ -r "${OPTIONS_FILE}" ]]; then
        value="$(jq -r --arg k "$1" \
            'if has($k) and .[$k] != null then .[$k] else empty end' \
            "${OPTIONS_FILE}" 2> /dev/null || true)"
    fi
    if [[ -n "${value}" ]]; then
        printf '%s' "${value}"
    else
        printf '%s' "${2:-}"
    fi
}

# opt_list <key>  -> prints one array element per line.
opt_list() {
    [[ -r "${OPTIONS_FILE}" ]] || return 0
    jq -r --arg k "$1" '(.[$k] // [])[]' "${OPTIONS_FILE}" 2> /dev/null || true
}
