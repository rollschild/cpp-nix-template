# `nix flake check` test of the generator: create a project with it, then check
# that every placeholder is filled in, the template-only parts are gone, and the
# result formats cleanly, builds and passes its tests. Nix itself is not
# available in the sandbox, so the generator skips `nix fmt` and the dev-preset
# configure (NEW_PROJECT_NO_NIX) and treefmt runs directly instead.
{
  runCommandCC,
  catch2_3,
  cmake,
  git,
  ninja,
  new-project,
  treefmtWrapper,
}:

runCommandCC "new-project-test"
  {
    nativeBuildInputs = [
      cmake
      git
      ninja
      new-project
      treefmtWrapper
    ];
    buildInputs = [ catch2_3 ];
  }
  ''
    export HOME=$TMPDIR
    git config --global user.name "Test User"
    git config --global user.email test@example.com
    cd "$TMPDIR"

    NEW_PROJECT_NO_NIX=1 new-project order_book 'Order book (L2) & `matching` engine.' </dev/null
    cd order_book

    # Every placeholder is filled in, and nothing template-only came along.
    if grep -rIn -F --exclude-dir=.git -e myproject -e MYPROJECT \
      -e 'C++23 project template with CMake presets and a Nix flake' -e 'template-only:' .; then
      echo "placeholders left (above)"; exit 1
    fi
    test ! -e nix/new-project
    test "$(git symbolic-ref --short HEAD)" = main
    grep -qF 'DESCRIPTION "Order book (L2) & `matching` engine"' CMakeLists.txt
    grep -qF 'description = "Order book (L2) & `matching` engine";' flake.nix
    grep -qF 'Order book (L2) & `matching` engine.' README.md
    grep -qE '^Copyright \(c\) [0-9]{4} Test User$' LICENSE
    test -f include/order_book/order_book.hpp
    test -f tests/order_book_test.cpp

    # It formats cleanly; nixfmt also proves the edited flake.nix still parses.
    treefmt --no-cache

    # It builds and passes its tests, as the Nix package would.
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_COMPILE_WARNING_AS_ERROR=ON
    cmake --build build
    ctest --test-dir build --output-on-failure

    touch $out
  ''
