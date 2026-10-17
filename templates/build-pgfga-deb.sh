#!/usr/bin/env bash
#
# Download {{ package_name }} {{ version }} release assets and package them as a .deb.
#
# Generated from a Jinja2 template; do not edit the rendered script by hand.
#
# Usage: ./build-{{ package_name }}-deb.sh
#   OUT_DIR  directory to write the .deb to (default: ./dist)
#
# Uses dpkg-deb when available, otherwise assembles the .deb with ar + tar
# (so it also works on macOS without extra tooling).

set -euo pipefail

PKG_NAME="{{ package_name }}"
VERSION="{{ version }}"
REVISION="{{ revision | default('1') }}"
ARCH="{{ package_arch | default('amd64') }}"

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

{% for asset in assets %}fetch_asset "{{ asset.name }}" "{{ asset.url }}"
{% endfor %}
# --- prep --------------------------------------------------------------------
(
  cd "${SRC_DIR}"
{% for cmd in prep | default([]) %}  {{ cmd }}
{% endfor %}  :
)

# --- package tree ------------------------------------------------------------
install_file() {
  local mode="$1" src="$2" dest="$3"
  mkdir -p "$(dirname "${PKG_ROOT}${dest}")"
  install -m "${mode}" "${SRC_DIR}/${src}" "${PKG_ROOT}${dest}"
}

{% for file in files %}install_file "{{ file.mode | default('0755') }}" "{{ file.src }}" "{{ file.dest }}"
{% endfor %}
INSTALLED_SIZE="$(du -sk "${PKG_ROOT}" | cut -f1)"

cat > "${PKG_ROOT}/DEBIAN/control" <<'EOF'
Package: {{ package_name }}
Version: {{ version }}-{{ revision | default('1') }}
Section: {{ section | default('misc') }}
Priority: {{ priority | default('optional') }}
Architecture: {{ package_arch | default('amd64') }}
Maintainer: {{ maintainer | default('pgvillage-tools <noreply@github.com>') }}
{% if requires %}Depends: {{ requires | join(', ') }}
{% endif %}{% if url %}Homepage: {{ url }}
{% endif %}Description: {{ description or package_name }}
{% for line in (long_description or description or package_name).splitlines() %} {{ line if line.strip() else '.' }}
{% endfor %}EOF
echo "Installed-Size: ${INSTALLED_SIZE}" >> "${PKG_ROOT}/DEBIAN/control"

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
