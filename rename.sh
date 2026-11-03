#!/usr/bin/env bash
# One-shot setup of a project created from this template: replaces "myproject"
# everywhere (C++ namespace, CMake targets, file names, Nix package), deletes
# itself, reformats, and stages the result in git (flakes only see tracked
# files).
#
# Usage: bash rename.sh [name]    # name defaults to the directory name
# The name must be lower_snake_case (it becomes a C++ namespace). If it isn't,
# the script asks for one, suggesting a converted name (Enter accepts it); with
# no terminal to ask on, it exits with an error instead.
set -euo pipefail
cd "$(dirname "$0")"

is_valid() { [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]]; }
# "Kafka-Lab 2" -> "kafka_lab_2"; empty if nothing usable is left
to_snake_case() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' |
        sed -e 's/^[^a-z]*//' -e 's/_*$//'
}

new="${1:-$(basename "$PWD")}"
if ! is_valid "$new"; then
    if [[ ! -t 0 ]]; then
        echo "error: '$new' is not lower_snake_case (it becomes a C++ namespace)" >&2
        echo "usage: bash rename.sh [name]" >&2
        exit 1
    fi
    suggestion="$(to_snake_case "$new")"
    echo "'$new' can't be the project name: it must be lower_snake_case (it becomes a C++ namespace)."
    while :; do
        read -r -p "Project name${suggestion:+ [$suggestion]}: " answer || {
            echo
            exit 1
        }
        new="${answer:-$suggestion}"
        is_valid "$new" && break
        echo "'$new' is not lower_snake_case (letters, digits, _; starting with a letter). Try again."
    done
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
