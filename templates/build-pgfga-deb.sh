#!/usr/bin/env bash
#
# Download a pgfga release tarball from GitHub and package it as a .deb.
#
# Usage: ./build-pgfga-deb.sh [VERSION] [OS] [ARCH]
#   VERSION  release version without leading "v" (default: 2.14.1)
#   OS       release OS: darwin or linux          (default: darwin)
#   ARCH     release arch: amd64 or arm64         (default: amd64)
#
# Uses dpkg-deb when available, otherwise assembles the .deb with ar + tar
# (so it also works on macOS without extra tooling).

set -euo pipefail

PKG_NAME="${1:-pgfga}"
VERSION="${2:-2.14.1}"
OS="${3:-darwin}"
ARCH="${4:-amd64}"

MAINTAINER="${MAINTAINER:-pgvillage-tools <noreply@github.com>}"
TARBALL="${PKG_NAME}_v${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/pgvillage-tools/pgfga/releases/download/v${VERSION}/${TARBALL}"
OUT_DIR="${OUT_DIR:-$(pwd)/dist}"
DEB_FILE="${OUT_DIR}/${PKG_NAME}_${VERSION}_${ARCH}.deb"

if [[ "${OS}" != "linux" ]]; then
  echo "WARNING: packaging a ${OS} binary; it will not run on Debian/Ubuntu." >&2
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# --- download & extract ------------------------------------------------------
echo "Downloading ${URL}"
curl -fsSL -o "${WORK_DIR}/${TARBALL}" "${URL}"

mkdir -p "${WORK_DIR}/src"
tar -xzf "${WORK_DIR}/${TARBALL}" -C "${WORK_DIR}/src"

# --- package tree ------------------------------------------------------------
PKG_ROOT="${WORK_DIR}/pkg"
install -d -m 0755 "${PKG_ROOT}/DEBIAN" \
  "${PKG_ROOT}/usr/bin" \
  "${PKG_ROOT}/usr/share/doc/${PKG_NAME}"
install -m 0755 "${WORK_DIR}/src/pgfga" "${PKG_ROOT}/usr/bin/pgfga"
install -m 0644 "${WORK_DIR}/src/LICENSE" "${PKG_ROOT}/usr/share/doc/${PKG_NAME}/copyright"
install -m 0644 "${WORK_DIR}/src/README.md" "${PKG_ROOT}/usr/share/doc/${PKG_NAME}/README.md"

INSTALLED_SIZE="$(du -sk "${PKG_ROOT}/usr" | cut -f1)"

cat > "${PKG_ROOT}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Maintainer: ${MAINTAINER}
Homepage: https://github.com/pgvillage-tools/pgfga
Description: PostgreSQL Fine Grained Access
 pgfga manages PostgreSQL users, roles, databases and permissions
 from a declarative configuration file.
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
    -C "${PKG_ROOT}/DEBIAN" ./control
  COPYFILE_DISABLE=1 tar "${OWNER_OPTS[@]}" -czf "${BUILD_DIR}/data.tar.gz" \
    -C "${PKG_ROOT}" ./usr
  (cd "${BUILD_DIR}" && ar rc "${DEB_FILE}" debian-binary control.tar.gz data.tar.gz)
fi

echo "Built ${DEB_FILE}"
