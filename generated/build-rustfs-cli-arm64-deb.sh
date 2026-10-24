#!/usr/bin/env bash
#
# Download rustfs-cli v0.1.36 release assets and package them as a .deb.
#
# Generated from a Jinja2 template; do not edit the rendered script by hand.
#
# Usage: ./build-rustfs-cli-deb.sh
#   OUT_DIR  directory to write the .deb to (default: ./dist)
#
# Uses dpkg-deb when available, otherwise assembles the .deb with ar + tar
# (so it also works on macOS without extra tooling).

set -euo pipefail

PKG_NAME="rustfs-cli"
# Debian versions must start with a digit, so strip the tag's leading "v".
VERSION="v0.1.36"
VERSION="${VERSION#v}"
REVISION="1"
ARCH="arm64"

OUT_DIR="${OUT_DIR:-$(pwd)/dist}"
DEB_FILE="${OUT_DIR}/${PKG_NAME}_${VERSION}-${REVISION}_${ARCH}.deb"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

SRC_DIR="${WORK_DIR}/src"
PKG_ROOT="${WORK_DIR}/pkg"
mkdir -p "${SRC_DIR}" "${PKG_ROOT}/DEBIAN"

# --- download & extract ------------------------------------------------------
fetch_asset() {
  local name="$1" url="$2"
  echo "Downloading ${url}"
  curl -fsSL -o "${WORK_DIR}/${name}" "${url}"
  case "${name}" in
    *.tar.gz | *.tgz | *.tar.xz | *.tar.bz2 | *.tar)
      tar -xf "${WORK_DIR}/${name}" -C "${SRC_DIR}" ;;
    *.zip)
      unzip -q -o "${WORK_DIR}/${name}" -d "${SRC_DIR}" ;;
    *)
      cp "${WORK_DIR}/${name}" "${SRC_DIR}/${name}" ;;
  esac
}

fetch_asset "rustfs-cli-linux-arm64-v0.1.36.tar.gz" "https://github.com/rustfs/cli/releases/download/v0.1.36/rustfs-cli-linux-arm64-v0.1.36.tar.gz"

# --- prep --------------------------------------------------------------------
(
  cd "${SRC_DIR}"
  :
)

# --- package tree ------------------------------------------------------------
install_file() {
  local mode="$1" src="$2" dest="$3"
  mkdir -p "$(dirname "${PKG_ROOT}${dest}")"
  install -m "${mode}" "${SRC_DIR}/${src}" "${PKG_ROOT}${dest}"
}

install_file "0755" "rc" "/usr/bin/rc"

INSTALLED_SIZE="$(du -sk "${PKG_ROOT}" | cut -f1)"

SYNOPSIS="$(cat <<'EOF'
A S3-compatible command-line client written in Rust.
EOF
)"
# Long description: one leading space per line, empty lines become " ."
LONG_DESCRIPTION="$(sed -e 's/^[[:space:]]*$/./' -e 's/^/ /' <<'EOF'
A S3-compatible command-line client written in Rust.
EOF
)"

cat > "${PKG_ROOT}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${REVISION}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: pgvillage-tools <noreply@github.com>
Installed-Size: ${INSTALLED_SIZE}
Homepage: https://github.com/rustfs/cli
Description: ${SYNOPSIS}
${LONG_DESCRIPTION}
EOF

# --- build .deb --------------------------------------------------------------
mkdir -p "${OUT_DIR}"
rm -f "${DEB_FILE}"

if command -v dpkg-deb >/dev/null 2>&1; then
  dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_FILE}"
else
  # Manual assembly: a .deb is an ar archive of debian-binary,
  # control.tar.gz and data.tar.gz (in that order).
  if tar --version 2>/dev/null | grep -q bsdtar; then
    OWNER_OPTS=(--uid 0 --gid 0 --uname root --gname root)
  else
    OWNER_OPTS=(--owner=0 --group=0 --numeric-owner)
  fi
  BUILD_DIR="${WORK_DIR}/deb"
  mkdir -p "${BUILD_DIR}"
  echo "2.0" > "${BUILD_DIR}/debian-binary"
  COPYFILE_DISABLE=1 tar "${OWNER_OPTS[@]}" -czf "${BUILD_DIR}/control.tar.gz" \
    -C "${PKG_ROOT}/DEBIAN" .
  COPYFILE_DISABLE=1 tar "${OWNER_OPTS[@]}" -czf "${BUILD_DIR}/data.tar.gz" \
    -C "${PKG_ROOT}" --exclude ./DEBIAN .
  (cd "${BUILD_DIR}" && ar rc "${DEB_FILE}" debian-binary control.tar.gz data.tar.gz)
fi

echo "Built ${DEB_FILE}"