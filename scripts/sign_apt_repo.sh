#!/bin/bash
#
# Sign the Release file of every suite in the apt repository (InRelease and Release.gpg)
# with the package manager key, and publish its public key in the repository root.
set -e

DEST=${DEST:-/host}
cd "$DEST"
export REPO_DIR=${REPO_DIR:-${DEST}/apt}
GPG_NAME=${GPG_NAME:-Package Manager}
ORIGIN=${ORIGIN:-pgvillage}

if [ -z "${GPG_KEY_B64}" ]; then
	echo "GPG_KEY_B64 is not set, cannot sign the apt repository" >&2
	exit 1
fi

# use a throw-away keyring, so the key does not end up in the keyring of the user running this
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "${GNUPGHOME}"' EXIT

if [ -e gpg_pubkey.asc ]; then
	echo "Importing pubkey..."
	gpg --import --no-tty --batch --yes <gpg_pubkey.asc
fi
echo "Importing seckey..."
echo "${GPG_KEY_B64}" | base64 -d | gpg --import --no-tty --batch --yes

function sign() {
	gpg --no-tty --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
		--local-user "${GPG_NAME}" "$@" <<<"${GPG_PASSPHRASE}"
}

for RELEASE in "${REPO_DIR}"/dists/*/Release; do
	if [ ! -e "${RELEASE}" ]; then
		echo "No Release files found in ${REPO_DIR}/dists, run build_apt_repo.sh first" >&2
		exit 1
	fi
	echo "Signing ${RELEASE}..."
	sign --clearsign --output "${RELEASE%/Release}/InRelease" "${RELEASE}"
	sign --armor --detach-sign --output "${RELEASE}.gpg" "${RELEASE}"
done

echo "Exporting pubkey..."
gpg --armor --export "${GPG_NAME}" >"${REPO_DIR}/${ORIGIN}.asc"

echo Signing finished succesfully
