# The package, in nixpkgs style. The flake and the overlay load it with
# `callPackage`, and you can copy it into nixpkgs.
{
  lib,
  stdenv,
  cmake,
  ninja,
  gtest,
}:

let
  # The name, version and description are from project(...) in CMakeLists.txt.
  project = import ./project.nix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = project.name;
  inherit (project) version;

  # Only the files that CMake uses. A change to the docs, scripts or Nix files
  # does not cause a rebuild.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../CMakeLists.txt
      ../cmake
      ../include
      ../src
      ../apps
      ../tests
      ../.clang-tidy # only the `tidy` check in flake.nix reads it
    ];
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  # Libraries that the project links to. CMake finds each with `find_package`.
  buildInputs = [ ];

  # Dependencies of the tests only. The build gets them only if doCheck is true.
  checkInputs = [ gtest ];

  cmakeFlags = [
    (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" true)
  ];

  # Run the tests (ctest) after the build. If false, the cmake hook sets
  # -DBUILD_TESTING=OFF, and GoogleTest is not necessary.
  doCheck = true;

  # Keep build-time and run-time dependencies separate. Then an input in the
  # wrong list causes an error.
  strictDeps = true;

  meta = {
    inherit (project) description;
    homepage = "https://github.com/rollschild/${finalAttrs.pname}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = finalAttrs.pname; # apps/ gives the executable the project name
  };
})
