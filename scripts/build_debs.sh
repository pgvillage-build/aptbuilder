#!/bin/bash
set -ex

[ -e /host ] && DEST=/host || DEST="$(cd "$(dirname "$0")/.." && pwd)"
export OUT_DIR=${OUT_DIR:-${DEST}/deb}

mkdir -p "${OUT_DIR}"
find "${DEST}/generated/" -name 'build-*-deb.sh' | sort | while read -r SCRIPT; do
	bash "${SCRIPT}"
done

ls "${OUT_DIR}/"*.deb

echo Building debs finished succesfully
