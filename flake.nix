{
  description = "C++23 project template with CMake presets and a Nix flake";

  inputs = {
    # Pin a channel that cache.nixos.org actually builds; `master` is not cached.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # One `nix fmt` entry point for C++, CMake, Python and Nix sources.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;

      # nixpkgs dropped x86_64-darwin in 26.11.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # { <system> = f pkgs; } for every supported system, no flake-utils needed.
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      treefmtFor = forAllSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix);
    in
    {
      # Consumers add this overlay and get `pkgs.myproject`.
      overlays.default = final: _prev: {
        myproject = final.callPackage ./nix/package.nix { };
      };

      packages = forAllSystems (
        pkgs:
        let
          myproject = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit myproject;
          default = myproject;
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/shell.nix {
          inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) myproject;
        };
      });

      # `nix flake check`: build and test with the default compiler and with
      # Clang, then verify formatting and lint.
      checks = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          inherit (self.packages.${system}) myproject;
        in
        {
          package = myproject;
          clang = myproject.override { stdenv = pkgs.clangStdenv; };
          formatting = treefmtFor.${system}.config.build.check self;
        }
      );

      # `nix fmt` formats the whole tree.
      formatter = forAllSystems (
        pkgs: treefmtFor.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );
      # template-only:begin (rename.sh deletes this block in new projects)

      # `nix flake new -t <this repo> <dir>` scaffolds a new project from this tree.
      templates.default = {
        path = ./.;
        description = "C++23 + CMake presets + Nix flake (direnv, Catch2, treefmt, Python scripts)";
        welcomeText = ''
          # New C++ project

          From the new project's directory:

          ```
          bash rename.sh                  # asks for a description (and a name if the directory's isn't valid)
          direnv allow                    # or: nix develop
          cmake --workflow --preset dev   # configure + build + test
          ```

          WORKFLOW.md has every command, in the order you use them.
        '';
      };
      # template-only:end
    };
}
