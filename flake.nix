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

      # Name, version and description, parsed from project(...) in CMakeLists.txt.
      project = import ./nix/project.nix;

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
      # Consumers add this overlay and get `pkgs.<project name>`.
      overlays.default = final: _prev: {
        ${project.name} = final.callPackage ./nix/package.nix { };
      };

      packages = forAllSystems (
        pkgs:
        let
          package = pkgs.callPackage ./nix/package.nix { };
        in
        {
          default = package;
          ${project.name} = package;
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/shell.nix {
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      });

      # `nix flake check`: build and test with the default compiler and with
      # Clang, then verify formatting and lint.
      checks = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          package = self.packages.${system}.default;
        in
        {
          inherit package;
          clang = package.override { stdenv = pkgs.clangStdenv; };
          formatting = treefmtFor.${system}.config.build.check self;
          # template-only:begin (new projects don't contain the generator)
          # The generator creates a project that formats, builds and passes its tests.
          new-project = pkgs.callPackage ./nix/new-project/test.nix {
            new-project = pkgs.callPackage ./nix/new-project { template = self.outPath; };
            treefmtWrapper = treefmtFor.${system}.config.build.wrapper;
          };
          # template-only:end
        }
      );

      # `nix fmt` formats the whole tree.
      formatter = forAllSystems (
        pkgs: treefmtFor.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );
      # template-only:begin (new projects don't contain the generator)

      # `nix run <this flake>#new -- <name> ["description"]` creates ./<name>
      # from this template, with every placeholder filled in.
      apps = forAllSystems (pkgs: {
        new = {
          type = "app";
          program = lib.getExe (pkgs.callPackage ./nix/new-project { template = self.outPath; });
          meta.description = "Create a new project from this template";
        };
      });
      # template-only:end
    };
}
