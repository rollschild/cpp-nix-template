# treefmt-nix module: one `nix fmt` for every language in the repo.
# `nix flake check` fails if anything is not formatted.
{ ... }:
{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true; # *.nix (RFC 166 style)
  programs.clang-format.enable = true; # C/C++, honours .clang-format
  programs.cmake-format.enable = true; # CMakeLists.txt, *.cmake
}
