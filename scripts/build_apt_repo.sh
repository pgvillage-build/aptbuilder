#!/bin/bash
#
# Add the deb packages from DEB_DIR to the apt repository in REPO_DIR and (re)generate
# the indexes for every codename and architecture found in the repository.
# Run sign_apt_repo.sh afterwards to sign the Release files.
#
# Packages are added for the codename of the system this runs on (from /etc/os-release,
# override with CODENAME), so running this on several distros / versions / architectures
# and merging the resulting REPO_DIR trees, and then running it once more, gives one
# repository that serves all of them:
#
#   apt/
#     <ORIGIN>.asc                                  public key (from sign_apt_repo.sh)
#     pool/<codename>/<component>/<p>/<package>/*.deb
#     dists/<codename>/Release
#     dists/<codename>/{InRelease,Release.gpg}      signatures (from sign_apt_repo.sh)
#     dists/<codename>/<component>/binary-<arch>/Packages{,.gz}
set -e

[ -e /host ] && DEST=/host || DEST="$(cd "$(dirname "$0")/.." && pwd)"
export DEB_DIR=${DEB_DIR:-${DEST}/deb}
export REPO_DIR=${REPO_DIR:-${DEST}/apt}
COMPONENT=${COMPONENT:-main}
ORIGIN=${ORIGIN:-pgvillage}
LABEL=${LABEL:-${ORIGIN}}
DESCRIPTION=${DESCRIPTION:-${LABEL} packages}

if [ -z "${CODENAME}" ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	CODENAME=${VERSION_CODENAME}
fi
if [ -z "${CODENAME}" ]; then
	echo "Cannot detect the codename of this system, please set CODENAME" >&2
	exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# --- add packages to the pool ------------------------------------------------
mkdir -p "${REPO_DIR}"
cd "${REPO_DIR}"

find "${DEB_DIR}" -maxdepth 1 -name '*.deb' | sort | while read -r DEB; do
	PACKAGE=$(dpkg-deb --field "${DEB}" Package)
	case "${PACKAGE}" in
		lib?*) PREFIX=${PACKAGE:0:4} ;;
		*) PREFIX=${PACKAGE:0:1} ;;
	esac
	POOL="pool/${CODENAME}/${COMPONENT}/${PREFIX}/${PACKAGE}"
	mkdir -p "${POOL}"
	echo "Adding ${DEB##*/} to ${POOL}"
	cp "${DEB}" "${POOL}/"
done

# --- (re)generate indexes for every codename in the pool ---------------------
for SUITE_POOL in pool/*/; do
	SUITE=$(basename "${SUITE_POOL}")
	SUITE_DIST="dists/${SUITE}"
	ARCHS=$(find "${SUITE_POOL}" -name '*.deb' -exec dpkg-deb --field {} Architecture \; |
		grep -vx all | sort -u | xargs)
	if [ -z "${ARCHS}" ]; then
		# only architecture independent packages; publish them for the arch of this system
		ARCHS=$(dpkg --print-architecture)
	fi
	echo "Generating indexes for ${SUITE} (${ARCHS})"

	rm -rf "${SUITE_DIST}"
	for ARCH in ${ARCHS}; do
		BINARY_DIR="${SUITE_DIST}/${COMPONENT}/binary-${ARCH}"
		mkdir -p "${BINARY_DIR}"
		apt-ftparchive --arch "${ARCH}" packages "${SUITE_POOL}" >"${BINARY_DIR}/Packages"
		gzip -9 --keep --force "${BINARY_DIR}/Packages"
	done

	apt-ftparchive \
		-o APT::FTPArchive::Release::Origin="${ORIGIN}" \
		-o APT::FTPArchive::Release::Label="${LABEL}" \
		-o APT::FTPArchive::Release::Suite="${SUITE}" \
		-o APT::FTPArchive::Release::Codename="${SUITE}" \
		-o APT::FTPArchive::Release::Architectures="${ARCHS}" \
		-o APT::FTPArchive::Release::Components="${COMPONENT}" \
		-o APT::FTPArchive::Release::Description="${DESCRIPTION}" \
		release "${SUITE_DIST}" >"${TMP_DIR}/Release"
	mv "${TMP_DIR}/Release" "${SUITE_DIST}/Release"
done

find "${REPO_DIR}" -type f | sort

echo Building apt repository finished succesfully
