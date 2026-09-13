#!/usr/bin/env bash
# Rename the template project. Usage: ./rename.sh <new_project_name>
# The name must be a valid C++ identifier in lower_snake_case.
set -euo pipefail

new="${1:?usage: ./rename.sh <new_project_name>}"
if [[ ! "$new" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "error: name must match ^[a-z][a-z0-9_]*$ (got '$new')" >&2
    exit 1
fi
NEW="$(printf '%s' "$new" | tr '[:lower:]' '[:upper:]')"

cd "$(dirname "$0")"

mv_() { if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$1" >/dev/null 2>&1; then git mv "$1" "$2"; else mv "$1" "$2"; fi; }

mv_ include/myproject "include/$new"
mv_ src/myproject.cpp "src/$new.cpp"
mv_ "include/$new/myproject.hpp" "include/$new/$new.hpp"
mv_ tests/myproject_test.cpp "tests/${new}_test.cpp"
mv_ cmake/myproject-config.cmake.in "cmake/$new-config.cmake.in"

# Replace identifiers in every tracked/regular file except this script.
find . -type f -not -path './.git/*' -not -path './build/*' -not -path './.direnv/*' -not -name rename.sh -print0 |
    xargs -0 perl -pi -e "s/MYPROJECT/$NEW/g; s/myproject/$new/g"

rm -- "$0"
echo "Renamed to '$new'. Now: git add -A && direnv allow && cmake --workflow --preset dev"
