# shellcheck shell=bash
# Makes a new project from this template. Run it through the flake:
#   nix run github:rollschild/cpp-nix-template#new -- <name> ["description"]
# nix/new-project/default.nix makes it a package (pinned tools, shellcheck at
# build time) and sets $TEMPLATE to the source of the template.
#
# It copies the template to ./<name> and replaces all placeholders:
#   - "myproject" and "MYPROJECT" -> the name (C++ namespace, CMake targets,
#     file and directory names). The Nix files read the name, version and
#     description from CMakeLists.txt (nix/project.nix).
#   - the placeholder description -> your description (CMakeLists.txt,
#     flake.nix, README.md)
#   - the LICENSE copyright line -> this year and your git user.name
# It does not copy this generator (nix/new-project/) or the blocks between the
# "template-only:begin" and "template-only:end" lines.
# Then it makes a git repository on `main` (the CI branch) and stages all
# files, because flakes see only tracked files. It runs `nix fmt` and
# configures the dev preset, so that clangd has compile_commands.json before
# you open the editor. At the end, it makes sure that no placeholder remains.
#
# The name must be lower_snake_case, because it is the C++ namespace. The
# generator asks for each value that you did not give or that is not correct.
# Without a terminal, it stops with an error. NEW_PROJECT_NO_NIX=1 tells it not
# to run `nix fmt` and the configure step: the flake check runs the generator
# in the sandbox, which has no Nix.

placeholder_description="C++23 project template with CMake presets and a Nix flake"
interactive=false
[[ -t 0 ]] && interactive=true

die() {
    printf 'error: %s\n' "$*" >&2
    echo 'usage: nix run github:rollschild/cpp-nix-template#new -- <name> ["one-line description"]' >&2
    exit 1
}
ask() { # ask <prompt>: sets $answer. Ctrl-D stops with no changes.
    read -r -p "$1" answer || {
        echo
        exit 1
    }
}

# --- Name ---------------------------------------------------------------------
is_valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]]; }
# "Kafka-Lab 2" -> "kafka_lab_2". If no letter remains, the result is empty.
to_snake_case() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' |
        sed -e 's/^[^a-z]*//' -e 's/_*$//'
}

name="${1:-}"
if ! is_valid_name "$name"; then
    if [[ -z "$name" ]]; then
        $interactive || die "a project name is necessary"
        suggestion=""
    else
        $interactive || die "'$name' is not lower_snake_case (the name is the C++ namespace)"
        suggestion="$(to_snake_case "$name")"
        echo "'$name' cannot be the project name. The name must be lower_snake_case, because it is the C++ namespace."
    fi
    while :; do
        ask "Project name${suggestion:+ [$suggestion]}: "
        name="${answer:-$suggestion}"
        is_valid_name "$name" && break
        echo "'$name' is not lower_snake_case. Use a-z, 0-9 and _, and start with a letter."
        suggestion="$(to_snake_case "$name")"
    done
fi
dest="$PWD/$name"
[[ ! -e "$dest" ]] || die "$dest exists"

# --- Description --------------------------------------------------------------
# One line, with no period at the end (nixpkgs style). The README adds a period.
normalize_description() {
    printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\.*$//'
}
description_problem() { # shows the problem with $1 (no text if $1 is correct)
    if [[ -z "$1" ]]; then
        echo "it is empty"
    elif [[ "$1" == *[\"\\\$]* ]]; then
        echo 'it contains " \ or $, which cause errors in CMake and Nix strings'
    elif [[ "$1" == "$placeholder_description" ]]; then
        echo "it is the template placeholder"
    fi
}

description="$(normalize_description "${2:-}")"
problem="$(description_problem "$description")"
if [[ -n "$problem" ]]; then
    if [[ -z "${2:-}" ]]; then
        $interactive || die "a one-line description is necessary"
        echo "Write a one-line description of $name. The generator puts it in CMakeLists.txt, flake.nix and README.md."
    else
        $interactive || die "you cannot use '$2' as the description: $problem"
        echo "You cannot use '$2' as the description: $problem."
    fi
    while :; do
        ask "Description: "
        description="$(normalize_description "$answer")"
        problem="$(description_problem "$description")"
        [[ -z "$problem" ]] && break
        echo "You cannot use that description: $problem."
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
    ask "Make the project? [Y/n] "
    [[ "$answer" =~ ^([yY]([eE][sS])?)?$ ]] || {
        echo "Stopped. The generator made no changes."
        exit 1
    }
fi

# --- Copy and replace placeholders --------------------------------------------
cp -r --no-preserve=mode,ownership "$TEMPLATE/." "$dest"
cd "$dest"
rm -rf nix/new-project
git init --quiet --initial-branch=main
git add --all

upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
# perl reads the values from the environment, so it inserts them without changes
export NEW_NAME="$name" NEW_UPPER="$upper" NEW_DESCRIPTION="$description" \
    NEW_PLACEHOLDER="$placeholder_description" \
    NEW_LICENSE_LINE="Copyright (c) $year $holder"

# shellcheck disable=SC2016 # $ENV{...} is perl code, which perl expands
git ls-files -z | xargs -0 perl -pi -e '
    s/myproject/$ENV{NEW_NAME}/g;
    s/MYPROJECT/$ENV{NEW_UPPER}/g;
    s/\Q$ENV{NEW_PLACEHOLDER}\E/$ENV{NEW_DESCRIPTION}/g;
'
{ git grep -l -z -e 'template-only:begin' || true; } |
    xargs -0 perl -ni -e 'print unless /template-only:begin/ .. /template-only:end/'
# shellcheck disable=SC2016
[[ -f LICENSE ]] && perl -pi -e 's/^Copyright \(c\) \d{4} .*$/$ENV{NEW_LICENSE_LINE}/' LICENSE

# File and directory names. The deepest paths go first, so that the parent
# directories change last.
find . -depth -name '*myproject*' -not -path './.git/*' |
    while IFS= read -r path; do
        mv "$path" "$(dirname "$path")/$(basename "$path" | sed "s/myproject/$name/g")"
    done
git add --all

configured=skipped
if [[ -z "${NEW_PROJECT_NO_NIX:-}" ]]; then
    # A name with a different length can change where lines wrap.
    nix fmt
    git add --all
    # clangd reads build/dev/compile_commands.json (.clangd). That file exists
    # only after the first configure. Without it, clangd uses default flags and
    # shows errors for the project headers and std::format. A clangd that
    # started before the file existed keeps these errors until a restart.
    echo "cmake --preset dev: this writes build/dev/compile_commands.json for clangd..."
    configured=yes
    if ! configure_log="$(nix develop --command cmake --preset dev 2>&1)"; then
        printf '%s\n' "$configure_log" | tail -n 20
        configured=failed
    fi
fi

# --- Report -------------------------------------------------------------------
leftovers="$(git grep -n -I -F -e myproject -e MYPROJECT -e "$placeholder_description" -e 'template-only:' || true)"
echo
echo "New project $name in $dest: $description"
if [[ -n "$leftovers" ]]; then
    echo "warning: these lines contain template placeholders:"
    printf '%s\n' "$leftovers"
fi
if [[ "$configured" == failed ]]; then
    echo "warning: the configure step stopped with an error (see the output above)."
    echo "Run 'cmake --preset dev' before you open the editor. If you do not, clangd"
    echo "shows errors for the project headers until you restart it."
fi
cat <<EOF
Next:
  cd $name
  direnv allow                    # load the dev shell
  cmake --workflow --preset dev   # build and test
Then replace the example code (greet) in these files:
  include/$name/$name.hpp  src/$name.cpp  apps/main.cpp  tests/${name}_test.cpp
WORKFLOW.md has all commands, in the sequence that you use them.
EOF
