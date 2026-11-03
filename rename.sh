#!/usr/bin/env bash
# One-shot setup of a project created from this template: replaces "myproject"
# everywhere (C++ namespace, CMake targets, file names, Nix package), deletes
# itself, reformats, and stages the result in git (flakes only see tracked
# files).
#
# Usage: bash rename.sh [name]    # name defaults to the directory name
set -euo pipefail
cd "$(dirname "$0")"

new="${1:-$(basename "$PWD")}"
if [[ ! "$new" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "error: '$new' is not lower_snake_case (it becomes a C++ namespace)" >&2
    echo "usage: bash rename.sh [name]" >&2
    exit 1
fi
upper="$(printf '%s' "$new" | tr '[:lower:]' '[:upper:]')"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init --quiet
git add --all

# File contents: every tracked file except this script.
git ls-files -z -- . ':!rename.sh' |
    xargs -0 perl -pi -e "s/myproject/$new/g; s/MYPROJECT/$upper/g"

# File and directory names, deepest first so parents are renamed last.
find . -depth -name '*myproject*' \
    -not -path './.git/*' -not -path './build/*' -not -path './.direnv/*' |
    while IFS= read -r path; do
        mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/myproject/$new/g")"
    done

rm -- "$0"
git add --all
# A name of different length can change line wrapping.
nix fmt
git add --all
echo "Renamed to '$new'. Next: direnv allow (or nix develop), then cmake --workflow --preset dev."
echo "WORKFLOW.md has every command, in the order you use them."
