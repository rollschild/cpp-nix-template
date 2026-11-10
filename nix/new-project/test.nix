# The `nix flake check` test of the generator. The test makes a project, then
# makes sure that:
#   - no placeholders and no template-only parts remain
#   - the format is correct
#   - the project builds, and its tests have no errors
# Nix is not available in the sandbox. NEW_PROJECT_NO_NIX tells the generator
# not to run `nix fmt` and the dev-preset configure. The test runs treefmt
# directly.
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

    # No placeholders and no template-only parts remain.
    if grep -rIn -F --exclude-dir=.git -e myproject -e MYPROJECT \
      -e 'C++23 project template with CMake presets and a Nix flake' -e 'template-only:' .; then
      echo "placeholders remain (see above)"; exit 1
    fi
    test ! -e nix/new-project
    test "$(git symbolic-ref --short HEAD)" = main
    grep -qF 'DESCRIPTION "Order book (L2) & `matching` engine"' CMakeLists.txt
    grep -qF 'description = "Order book (L2) & `matching` engine";' flake.nix
    grep -qF 'Order book (L2) & `matching` engine.' README.md
    grep -qE '^Copyright \(c\) [0-9]{4} Test User$' LICENSE
    test -f include/order_book/order_book.hpp
    test -f tests/order_book_test.cpp

    # The format is correct. nixfmt also makes sure that Nix can parse the
    # changed flake.nix.
    treefmt --no-cache

    # Build and test as the Nix package does.
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_COMPILE_WARNING_AS_ERROR=ON
    cmake --build build
    ctest --test-dir build --output-on-failure

    touch $out
  ''
