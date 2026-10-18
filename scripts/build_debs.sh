#!/bin/bash
set -ex

[ -e /host ] && DEST=/host || DEST="$(cd "$(dirname "$0")/.." && pwd)"
export OUT_DIR=${OUT_DIR:-${DEST}/deb}
# only build the scripts for the architecture of this system (all of them when dpkg is missing)
DEB_ARCH=${DEB_ARCH:-$(dpkg --print-architecture 2>/dev/null || echo '*')}

mkdir -p "${OUT_DIR}"
find "${DEST}/generated/" -name "build-*-${DEB_ARCH}-deb.sh" | sort | while read -r SCRIPT; do
	bash "${SCRIPT}"
done

bash "${DEST}/scripts/fetch_debs.sh"

ls "${OUT_DIR}/"*.deb

echo Building debs finished succesfully
