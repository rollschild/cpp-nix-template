# The package expression, written nixpkgs-style so it can be `callPackage`d
# from the flake, from an overlay, or copied into nixpkgs later.
{
  lib,
  stdenv,
  cmake,
  ninja,
  catch2_3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "myproject";
  version = "0.1.0";

  # Only what CMake needs. Editing README.md, flake.nix or the presets does not
  # invalidate the build.
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
    (lib.cmakeBool "MYPROJECT_WARNINGS_AS_ERRORS" true)
  ];

  # The cmake hook also passes -DBUILD_TESTING=OFF when this is false, and the
  # ninja hook runs the `test` target (ctest) when it is true.
  doCheck = true;

  # Keep build-time and run-time dependencies separate (catches misplaced inputs).
  strictDeps = true;

  meta = {
    description = "A C++23 project template";
    homepage = "https://github.com/rollschild/${finalAttrs.pname}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "myproject";
  };
})
