# The package, written nixpkgs-style so it can be `callPackage`d from the flake,
# from an overlay, or copied into nixpkgs later.
{
  lib,
  stdenv,
  cmake,
  ninja,
  catch2_3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "myproject";
  # Read from `project(... VERSION x.y.z ...)` in CMakeLists.txt, so a version
  # bump is a one-line change there.
  version = lib.head (
    builtins.match ".*project\\([^)]*VERSION[[:space:]]+([^[:space:])]+).*" (
      builtins.readFile ../CMakeLists.txt
    )
  );

  # Only what CMake needs: editing docs, scripts or Nix files never rebuilds.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../CMakeLists.txt
      ../cmake
      ../include
      ../src
      ../apps
      ../tests
    ];
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  # Libraries the project links against; each becomes a `find_package` target.
  buildInputs = [ ];

  # Test-only dependencies, added to the build only when doCheck is true.
  checkInputs = [ catch2_3 ];

  cmakeFlags = [
    (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" true)
  ];

  # Run the tests (ctest) after building. When false, the cmake hook passes
  # -DBUILD_TESTING=OFF, so Catch2 is not needed at all.
  doCheck = true;

  # Keep build-time and run-time dependencies separate (catches misplaced inputs).
  strictDeps = true;

  meta = {
    description = "C++23 project template with CMake presets and a Nix flake";
    homepage = "https://github.com/rollschild/${finalAttrs.pname}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "myproject";
  };
})
