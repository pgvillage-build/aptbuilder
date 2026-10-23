#!/bin/bash
#
# Bump the release tags in generated/prebuilt-debs.txt to the latest release of each
# repository. Needs gh (with GITHUB_TOKEN set in CI).
set -e

DEST="$(cd "$(dirname "$0")/.." && pwd)"
PREBUILT=${PREBUILT:-${DEST}/generated/prebuilt-debs.txt}

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

while read -r LINE; do
	case "${LINE}" in
		'' | '#'*) echo "${LINE}"; continue ;;
	esac
	read -r REPO PACKAGE TAG <<<"${LINE}"
	LATEST=$(gh release view --repo "${REPO}" --json tagName --jq .tagName)
	[ "${LATEST}" != "${TAG}" ] && echo "${PACKAGE}: ${TAG} -> ${LATEST}" >&2
	echo "${REPO} ${PACKAGE} ${LATEST}"
done <"${PREBUILT}" >"${TMP}"

cat "${TMP}" >"${PREBUILT}"
