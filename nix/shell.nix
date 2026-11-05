# Developer shell. Inherits every build and test dependency from the package so
# the two never drift apart, then adds tools you only want at the keyboard.
{
  lib,
  stdenv,
  buildEnv,
  mkShell,
  package,
  clang-tools,
  gdb,
  gersemi,
  nixfmt,
  python3,
  ruff,
}:

mkShell {
  name = "${package.pname}-dev";

  inputsFrom = [ package ];

  packages = [
    clang-tools # clangd, clang-tidy, clang-format
    # The formatters `nix fmt` runs (nix/treefmt.nix), on PATH so that editor
    # format-on-save produces exactly what CI checks. gersemi is a Python
    # application: exposing only its bin/ keeps its propagated interpreter and
    # libraries out of the shell, where they would shadow python3 below and
    # leak into PYTHONPATH.
    (buildEnv {
      name = "gersemi";
      paths = [ gersemi ];
      pathsToLink = [ "/bin" ];
    })
    nixfmt
    ruff
    # Python for scripts/. Add libraries from nixpkgs, e.g. `ps: [ ps.numpy ]`.
    (python3.withPackages (ps: [ ]))
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ gdb ];

  # The cc-wrapper's fortify hardening prepends -O2, which silently optimises
  # Debug builds, and an explicit -O0 then trips glibc's _FORTIFY_SOURCE
  # #warning (fatal under -Werror). Only the dev shell drops it; the Nix
  # package keeps all hardening.
  hardeningDisable = [ "fortify" ];
}
