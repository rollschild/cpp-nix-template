# treefmt-nix module: one `nix fmt` for all languages in the repository.
# `nix flake check` shows an error if a file has format or lint errors. The
# dev shell (nix/shell.nix) puts the same tools on PATH for the editor.
{ lib, pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs.clang-format.enable = true; # C++, reads .clang-format
  programs.nixfmt.enable = true; # *.nix, RFC 166 style
  programs.ruff-check.enable = true; # Python lint with automatic fixes, reads ruff.toml
  programs.ruff-format.enable = true; # Python format, reads ruff.toml

  # CMake. gersemi replaces cmake-format, which has had no release since 2020.
  # treefmt-nix has no module for gersemi, so this is a plain formatter.
  settings.formatter.gersemi = {
    command = lib.getExe pkgs.gersemi;
    options = [ "--in-place" ];
    includes = [
      "CMakeLists.txt"
      "*/CMakeLists.txt" # in treefmt globs, `*` includes `/`
      "*.cmake"
    ];
  };
}
