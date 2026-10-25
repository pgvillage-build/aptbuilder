#!/bin/bash
#
# Download the prebuilt debs listed in config/prebuilt-debs.txt for the distro and
# architecture of this system into OUT_DIR.
#
# These repositories build a deb per distro with revision 1~<ID><VERSION_ID> (from
# /etc/os-release). GitHub replaces the ~ with a . in release asset names, so the asset
# is named e.g. wal-g-pg_3.0.9b-1.ubuntu24.04_amd64.deb.
# Distros a repository does not build for are skipped with a warning.
set -e

[ -e /host ] && DEST=/host || DEST="$(cd "$(dirname "$0")/.." && pwd)"
export OUT_DIR=${OUT_DIR:-${DEST}/deb}
PREBUILT=${PREBUILT:-${DEST}/config/prebuilt-debs.txt}
DEB_ARCH=${DEB_ARCH:-$(dpkg --print-architecture)}

# shellcheck disable=SC1091
DIST="$(. /etc/os-release && echo "${ID}${VERSION_ID}")"

mkdir -p "${OUT_DIR}"
grep -vE '^\s*(#|$)' "${PREBUILT}" | while read -r REPO PACKAGE TAG; do
	# PACKAGES (space separated) limits the packages, all of them when empty
	if [ -n "${PACKAGES}" ] && [[ " ${PACKAGES} " != *" ${PACKAGE} "* ]]; then
		continue
	fi
	# same version mangling as build-deb.sh in the source repository
	VERSION="${TAG%-*}"
	VERSION="${VERSION#v}"
	DEB="${PACKAGE}_${VERSION}-1.${DIST}_${DEB_ARCH}.deb"
	URL="https://github.com/${REPO}/releases/download/${TAG}/${DEB}"
	echo "Downloading ${URL}"
	if ! curl -fsSL --retry 3 -o "${OUT_DIR}/${DEB}" "${URL}"; then
		rm -f "${OUT_DIR}/${DEB}"
		echo "WARNING: ${REPO} ${TAG} has no ${DEB}, skipping ${PACKAGE} for ${DIST}" >&2
	fi
done
