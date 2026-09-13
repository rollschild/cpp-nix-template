# Developer shell. Inherits every build dependency from the package so the two
# never drift apart, then adds tools you only want at the keyboard.
{
  lib,
  stdenv,
  mkShell,
  myproject,
  clang-tools,
  cmake-format,
  gdb,
}:

mkShell {
  name = "myproject-dev";

  inputsFrom = [ myproject ];

  packages = [
    clang-tools # clangd, clang-tidy, clang-format
    cmake-format
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ gdb ];

  # nixpkgs' compiler wrapper injects -D_FORTIFY_SOURCE, which glibc rejects
  # at -O0 with a #warning. Under -Werror that breaks Debug builds.
  hardeningDisable = [ "fortify" ];
}
