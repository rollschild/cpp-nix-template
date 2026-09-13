{
  description = "myproject: a C++23 project built with CMake and packaged with Nix";

  inputs = {
    # Pin a channel that cache.nixos.org actually builds; `master` is not cached.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # One `nix fmt` entry point for C++, CMake and Nix sources.
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

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
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

      # `nix flake check`: build + run the test suite, then verify formatting.
      checks = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          package = self.packages.${system}.myproject;
          formatting = treefmtFor.${system}.config.build.check self;
        }
      );

      # `nix fmt` formats the whole tree.
      formatter = forAllSystems (
        pkgs: treefmtFor.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );

      # `nix flake init -t <this repo>` scaffolds a new project from this tree.
      templates.default = {
        path = ./.;
        description = "C++23 + CMake presets + Nix flake (direnv, Catch2, treefmt)";
        welcomeText = ''
          # myproject template

          `nix flake init` does not preserve file modes, so invoke the rename
          script through bash:

          ```
          bash rename.sh <new_project_name>
          git init && git add -A          # flakes only see tracked files
          direnv allow                    # or: nix develop
          cmake --workflow --preset dev   # configure + build + test
          ```
        '';
      };
    };
}
