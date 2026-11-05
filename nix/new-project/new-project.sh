# shellcheck shell=bash
# Creates a new project from this template. Run it through the flake:
#   nix run github:rollschild/cpp-nix-template#new -- <name> ["description"]
# nix/new-project/default.nix packages it (pinned tools, shellcheck at build
# time) and sets $TEMPLATE to the template's source.
#
# It copies the template into ./<name> and fills in every placeholder:
#   - "myproject" / "MYPROJECT" -> the name (C++ namespace, CMake targets,
#     file and directory names). The Nix files read the name, version and
#     description from CMakeLists.txt instead (nix/project.nix).
#   - the placeholder description -> yours (CMakeLists.txt, flake.nix, README.md)
#   - the LICENSE copyright line -> this year and your git user.name
#   - blocks between "template-only:begin" and "template-only:end" lines, and
#     this generator (nix/new-project/), are not copied into the project
# Then it starts git on `main` (the branch CI runs on), stages everything
# (flakes only see tracked files), runs `nix fmt`, configures the dev preset
# (so clangd has compile_commands.json before the editor opens), and checks
# that no placeholder is left.
#
# The name must be lower_snake_case (it becomes a C++ namespace). Whatever is
# missing or invalid is asked for interactively; without a terminal, that is an
# error instead. NEW_PROJECT_NO_NIX=1 skips `nix fmt` and the configure step
# (the flake check runs the generator in the sandbox, where Nix is unavailable).

placeholder_description="C++23 project template with CMake presets and a Nix flake"
interactive=false
[[ -t 0 ]] && interactive=true

die() {
    printf 'error: %s\n' "$*" >&2
    echo 'usage: nix run github:rollschild/cpp-nix-template#new -- <name> ["one-line description"]' >&2
    exit 1
}
ask() { # ask <prompt>: sets $answer; Ctrl-D aborts without creating anything
    read -r -p "$1" answer || {
        echo
        exit 1
    }
}

# --- Name ---------------------------------------------------------------------
is_valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]]; }
# "Kafka-Lab 2" -> "kafka_lab_2"; empty if nothing usable is left
to_snake_case() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' |
        sed -e 's/^[^a-z]*//' -e 's/_*$//'
}

name="${1:-}"
if ! is_valid_name "$name"; then
    if [[ -z "$name" ]]; then
        $interactive || die "a project name is required"
        suggestion=""
    else
        $interactive || die "'$name' is not lower_snake_case (it becomes a C++ namespace)"
        suggestion="$(to_snake_case "$name")"
        echo "'$name' can't be the project name: it must be lower_snake_case (it becomes a C++ namespace)."
    fi
    while :; do
        ask "Project name${suggestion:+ [$suggestion]}: "
        name="${answer:-$suggestion}"
        is_valid_name "$name" && break
        echo "'$name' is not lower_snake_case (letters, digits, _; starting with a letter)."
        suggestion="$(to_snake_case "$name")"
    done
fi
dest="$PWD/$name"
[[ ! -e "$dest" ]] || die "$dest already exists"

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
        echo "Describe $name in one line. It goes into CMakeLists.txt (which the Nix files read), flake.nix and README.md."
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

# --- License holder -----------------------------------------------------------
year="$(date +%Y)"
holder="$(git config user.name || true)"
[[ -n "$holder" ]] || holder="$(sed -n 's/^Copyright (c) [0-9]\{4\} //p' "$TEMPLATE/LICENSE")"

if $interactive; then
    echo
    echo "  directory:   $dest"
    echo "  name:        $name"
    echo "  description: $description"
    echo "  license:     MIT, Copyright (c) $year $holder"
    echo "  git:         new repository, branch main"
    ask "Create the project? [Y/n] "
    [[ "$answer" =~ ^([yY]([eE][sS])?)?$ ]] || {
        echo "Nothing created."
        exit 1
    }
fi

# --- Create -------------------------------------------------------------------
cp -r --no-preserve=mode,ownership "$TEMPLATE/." "$dest"
cd "$dest"
rm -rf nix/new-project
git init --quiet --initial-branch=main
git add --all

upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
# perl reads the values from the environment, so they are inserted literally
export NEW_NAME="$name" NEW_UPPER="$upper" NEW_DESCRIPTION="$description" \
    NEW_PLACEHOLDER="$placeholder_description" \
    NEW_LICENSE_LINE="Copyright (c) $year $holder"

# shellcheck disable=SC2016 # $ENV{...} is perl, expanded by perl
git ls-files -z | xargs -0 perl -pi -e '
    s/myproject/$ENV{NEW_NAME}/g;
    s/MYPROJECT/$ENV{NEW_UPPER}/g;
    s/\Q$ENV{NEW_PLACEHOLDER}\E/$ENV{NEW_DESCRIPTION}/g;
'
{ git grep -l -z -e 'template-only:begin' || true; } |
    xargs -0 perl -ni -e 'print unless /template-only:begin/ .. /template-only:end/'
# shellcheck disable=SC2016
[[ -f LICENSE ]] && perl -pi -e 's/^Copyright \(c\) \d{4} .*$/$ENV{NEW_LICENSE_LINE}/' LICENSE

# File and directory names, deepest first so parents are renamed last.
find . -depth -name '*myproject*' -not -path './.git/*' |
    while IFS= read -r path; do
        mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/myproject/$name/g")"
    done
git add --all

configured=skipped
if [[ -z "${NEW_PROJECT_NO_NIX:-}" ]]; then
    # A name of different length can change line wrapping.
    nix fmt
    git add --all
    # clangd reads build/dev/compile_commands.json (.clangd), which only exists
    # after the first configure. Without it, clangd guesses the flags and
    # reports missing project headers and std::format; a clangd that started
    # before the file appeared keeps reporting them until restarted.
    echo "Configuring the dev preset, so clangd has build/dev/compile_commands.json from the start..."
    configured=yes
    if ! configure_log="$(nix develop --command cmake --preset dev 2>&1)"; then
        printf '%s\n' "$configure_log" | tail -n 20
        configured=failed
    fi
fi

# --- Report -------------------------------------------------------------------
leftovers="$(git grep -n -I -F -e myproject -e MYPROJECT -e "$placeholder_description" -e 'template-only:' || true)"
echo
echo "Created $name in $dest: $description"
if [[ -n "$leftovers" ]]; then
    echo "warning: template placeholders are still present:"
    printf '%s\n' "$leftovers"
fi
if [[ "$configured" == failed ]]; then
    echo "warning: configuring failed (output above). Run 'cmake --preset dev' before opening"
    echo "the editor, or clangd reports missing headers until you restart it."
fi
cat <<EOF
Next:
  cd $name
  direnv allow                    # or: nix develop
  cmake --workflow --preset dev   # build + test
Then replace the template's example code (greet) with your own:
  include/$name/$name.hpp  src/$name.cpp  apps/main.cpp  tests/${name}_test.cpp
WORKFLOW.md has every command, in the order you use them.
EOF
