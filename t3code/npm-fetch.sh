#!/usr/bin/env bash
# Download an npm registry tarball and verify it against the registry's
# sha512 integrity value.
# Usage: npm-fetch.sh <package> <tarball-basename> <version> <dest>
set -euo pipefail

pkg="$1"
base="$2"
version="$3"
dest="$4"
registry="https://registry.npmjs.org"

integrity="$(curl -fsSL --retry 5 --retry-all-errors "${registry}/${pkg}/${version}" | jq -r '.dist.integrity')"
if [[ "${integrity}" != sha512-* ]]; then
    echo "No sha512 integrity found for ${pkg}@${version}" >&2
    exit 1
fi
expected="$(printf '%s' "${integrity#sha512-}" | base64 -d | od -An -vtx1 | tr -d ' \n')"

curl -fsSL --retry 5 --retry-all-errors -o "${dest}" "${registry}/${pkg}/-/${base}-${version}.tgz"
actual="$(sha512sum "${dest}" | cut -d' ' -f1)"
if [[ "${actual}" != "${expected}" ]]; then
    echo "Integrity mismatch for ${pkg}@${version}" >&2
    exit 1
fi
echo "Verified ${pkg}@${version}"
