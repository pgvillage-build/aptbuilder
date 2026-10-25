#!/bin/bash
#
# Print the packages that HEAD changes compared to BASE (default origin/main), space separated:
# the entries that are added or changed in config/github2spec.yaml and config/prebuilt-debs.txt.
# Prints "all" when any other file changed (templates, scripts, workflows, ...), or when nothing is
# left to build (only removals), so CI then builds everything.
# Needs python3 with PyYAML.
set -e

BASE=${1:-origin/main}
cd "$(dirname "$0")/.."

CONFIG=config/github2spec.yaml
PREBUILT=config/prebuilt-debs.txt

MERGE_BASE=$(git merge-base "${BASE}" HEAD)
for FILE in $(git diff --name-only "${MERGE_BASE}" HEAD); do
	case "${FILE}" in
		"${CONFIG}" | "${PREBUILT}") ;;
		*) echo all; exit 0 ;;
	esac
done

PACKAGES=$(
	# entries in the config that are new or have other values (comments don't count)
	python3 -c '
import sys, yaml
old, new = (yaml.safe_load(open(f)) for f in sys.argv[1:])
repos = lambda c: c.pop("repositories", None) or {}
old_repos, new_repos = repos(old), repos(new)
if old != new:
    print("all")
for name, values in new_repos.items():
    if old_repos.get(name) != values:
        print(name)
' <(git show "${MERGE_BASE}:${CONFIG}") "${CONFIG}"

	# lines in prebuilt-debs.txt that are new or have another tag
	comm -13 <(git show "${MERGE_BASE}:${PREBUILT}" | grep -vE '^\s*(#|$)' | sort) \
		<(grep -vE '^\s*(#|$)' "${PREBUILT}" | sort) | awk '{print $2}'
)

if [ -z "${PACKAGES}" ] || grep -qx all <<<"${PACKAGES}"; then
	echo all
else
	sort -u <<<"${PACKAGES}" | xargs
fi
