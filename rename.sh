#!/usr/bin/env bash
# One-shot setup of a project created from this template. It fills in every
# placeholder and removes the template-only parts:
#   - "myproject" / "MYPROJECT" -> the project name (C++ namespace, CMake
#     targets, Nix package), in file contents and in file and directory names
#   - the placeholder description -> yours (CMakeLists.txt, nix/package.nix,
#     flake.nix, README.md)
#   - the LICENSE copyright line -> this year and your git user.name
#   - blocks between "template-only:begin" and "template-only:end" lines are
#     deleted (e.g. the flake's `templates` output)
# It then starts git on `main` (the branch CI runs on), reformats, stages
# everything (flakes only see tracked files), checks that no placeholder is
# left, and deletes itself.
#
# Usage: bash rename.sh [name] [description]
# The name defaults to the directory name and must be lower_snake_case (it
# becomes a C++ namespace). Whatever is missing or invalid is asked for
# interactively; without a terminal, that is an error instead.
set -euo pipefail
cd "$(dirname "$0")"

placeholder_description="C++23 project template with CMake presets and a Nix flake"
interactive=false
[[ -t 0 ]] && interactive=true

die() {
    printf 'error: %s\n' "$*" >&2
    echo 'usage: bash rename.sh [name] ["one-line description"]' >&2
    exit 1
}
ask() { # ask <prompt>: sets $answer; Ctrl-D aborts without changing anything
    read -r -p "$1" answer || {
        echo
        exit 1
    }
}

if git rev-parse --verify --quiet HEAD >/dev/null 2>&1 && git cat-file -e HEAD:rename.sh 2>/dev/null; then
    die "rename.sh is committed here, so this is the template repository (or a clone that kept its history). Run it in a new project: nix flake new -t <template> <dir>"
fi

# --- Name ---------------------------------------------------------------------
is_valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]]; }
# "Kafka-Lab 2" -> "kafka_lab_2"; empty if nothing usable is left
to_snake_case() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' |
        sed -e 's/^[^a-z]*//' -e 's/_*$//'
}

name="${1:-$(basename "$PWD")}"
if ! is_valid_name "$name"; then
    $interactive || die "'$name' is not lower_snake_case (it becomes a C++ namespace)"
    suggestion="$(to_snake_case "$name")"
    echo "'$name' can't be the project name: it must be lower_snake_case (it becomes a C++ namespace)."
    while :; do
        ask "Project name${suggestion:+ [$suggestion]}: "
        name="${answer:-$suggestion}"
        is_valid_name "$name" && break
        echo "'$name' is not lower_snake_case (letters, digits, _; starting with a letter). Try again."
    done
fi

# --- Description --------------------------------------------------------------
# One line, no trailing period (nixpkgs style); the README adds its own period.
normalize_description() {
    printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\.*$//'
}
description_problem() { # prints why $1 can't be used; nothing if it can
    if [[ -z "$1" ]]; then
        echo "it is empty"
    elif [[ "$1" == *[\"\\\$]* ]]; then
        echo 'it contains " \ or $, which break CMake and Nix strings'
    elif [[ "$1" == "$placeholder_description" ]]; then
        echo "it is the template's placeholder"
    fi
}

description="$(normalize_description "${2:-}")"
problem="$(description_problem "$description")"
if [[ -n "$problem" ]]; then
    if [[ -z "${2:-}" ]]; then
        $interactive || die "a one-line description is required"
        echo "Describe $name in one line. It goes into CMakeLists.txt, nix/package.nix, flake.nix and README.md."
    else
        $interactive || die "can't use '$2' as the description: $problem"
        echo "Can't use '$2' as the description: $problem."
    fi
    while :; do
        ask "Description: "
        description="$(normalize_description "$answer")"
        problem="$(description_problem "$description")"
        [[ -z "$problem" ]] && break
        echo "Can't use that: $problem."
    done
fi

# --- License holder, git ------------------------------------------------------
year="$(date +%Y)"
holder="$(git config user.name || true)"
[[ -n "$holder" ]] || holder="$(sed -n 's/^Copyright (c) [0-9]\{4\} //p' LICENSE)"
new_repo=true
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && new_repo=false

if $interactive; then
    echo
    echo "  name:        $name"
    echo "  description: $description"
    echo "  license:     MIT, Copyright (c) $year $holder"
    $new_repo && echo "  git:         new repository, branch main"
    ask "Set up the project with these? [Y/n] "
    [[ "$answer" =~ ^([yY]([eE][sS])?)?$ ]] || {
        echo "Nothing changed."
        exit 1
    }
fi

# --- Apply --------------------------------------------------------------------
$new_repo && git init --quiet --initial-branch=main
git add --all

upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
# perl reads the values from the environment, so they are inserted literally
export RENAME_NAME="$name" RENAME_UPPER="$upper" RENAME_DESCRIPTION="$description" \
    RENAME_PLACEHOLDER="$placeholder_description" \
    RENAME_LICENSE_LINE="Copyright (c) $year $holder"

# File contents: every tracked file except this script.
# shellcheck disable=SC2016 # $ENV{...} is perl, expanded by perl
git ls-files -z -- . ':!rename.sh' | xargs -0 perl -pi -e '
    s/myproject/$ENV{RENAME_NAME}/g;
    s/MYPROJECT/$ENV{RENAME_UPPER}/g;
    s/\Q$ENV{RENAME_PLACEHOLDER}\E/$ENV{RENAME_DESCRIPTION}/g;
'
{ git grep -l -z -e 'template-only:begin' -- . ':!rename.sh' || true; } |
    xargs -0 perl -ni -e 'print unless /template-only:begin/ .. /template-only:end/'
[[ -f LICENSE ]] && perl -pi -e 's/^Copyright \(c\) \d{4} .*$/$ENV{RENAME_LICENSE_LINE}/' LICENSE

# File and directory names, deepest first so parents are renamed last.
find . -depth -name '*myproject*' \
    -not -path './.git/*' -not -path './build/*' -not -path './.direnv/*' |
    while IFS= read -r path; do
        mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/myproject/$name/g")"
    done

rm -- "$0"
git add --all
# A name of different length can change line wrapping.
nix fmt
git add --all

# --- Report -------------------------------------------------------------------
leftovers="$(git grep -n -I -F -e myproject -e MYPROJECT -e "$placeholder_description" -e 'template-only:' || true)"
echo
echo "Set up $name: $description"
if [[ -n "$leftovers" ]]; then
    echo "warning: template placeholders are still present:"
    printf '%s\n' "$leftovers"
fi
cat <<EOF
Next:
  direnv allow                    # or: nix develop
  cmake --workflow --preset dev   # configure + build + test
Then replace the template's example code (greet) with your own:
  include/$name/$name.hpp  src/$name.cpp  apps/main.cpp  tests/${name}_test.cpp
WORKFLOW.md has every command, in the order you use them.
EOF
