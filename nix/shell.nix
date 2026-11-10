# The dev shell. It gets all build and test dependencies from the package, so
# the two always agree. It also adds tools for interactive use.
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
    # The `nix fmt` formatters (nix/treefmt.nix) are on PATH, so that
    # format-on-save in the editor gives the same result as CI. gersemi is a
    # Python application, and only its bin/ goes into the shell. If all of
    # gersemi goes in, its Python interpreter and libraries go in too. Then
    # `python3` can be the wrong interpreter, and PYTHONPATH changes.
    (buildEnv {
      name = "gersemi";
      paths = [ gersemi ];
      pathsToLink = [ "/bin" ];
    })
    nixfmt
    ruff
    # Python for scripts/. Add libraries from nixpkgs, for example
    # `ps: [ ps.numpy ]`.
    (python3.withPackages (ps: [ ]))
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ gdb ];

  # No compiler-wrapper hardening in the dev shell. Then dev builds use only the
  # flags that CMake and compile_commands.json (clangd, clang-tidy) show.
  # Without this line, the wrapper adds flags that are not visible, for example:
  #   - -fno-strict-overflow: signed overflow wraps, so UBSan cannot find it
  #   - fortify adds -O2: Debug builds are optimized
  #   - -fzero-call-used-regs, stack protector and stack-clash probes: more
  #     instructions in all functions that you disassemble or benchmark
  # The Nix package (nix build, nix flake check) keeps the full nixpkgs
  # hardening, because you ship it.
  hardeningDisable = [ "all" ];
}
