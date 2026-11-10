{
  description = "C++23 project template with CMake presets and a Nix flake";

  inputs = {
    # cache.nixos.org has binaries for this branch, but not for `master`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # One `nix fmt` command for C++, CMake, Python and Nix files.
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

      # The name, version and description, from project(...) in CMakeLists.txt.
      project = import ./nix/project.nix;

      # nixpkgs 26.11 does not support x86_64-darwin.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # { <system> = f pkgs; } for each system. flake-utils is not necessary.
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      treefmtFor = forAllSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./nix/treefmt.nix);
    in
    {
      # With this overlay, other flakes get `pkgs.<project name>`.
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
      # Clang, run clang-tidy on all files, and do the format and lint checks.
      checks = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          package = self.packages.${system}.default;
        in
        {
          inherit package;
          clang = package.override { stdenv = pkgs.clangStdenv; };
          # clang-tidy on all translation units, also the tests. Each warning is
          # an error (.clang-tidy).
          tidy = package.overrideAttrs (old: {
            pname = "${old.pname}-tidy";
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.clang-tools ];
            cmakeFlags = old.cmakeFlags ++ [
              "-DCMAKE_CXX_CLANG_TIDY=clang-tidy;--extra-arg=-Wno-unknown-warning-option"
            ];
          });
          formatting = treefmtFor.${system}.config.build.check self;
          # template-only:begin (new projects do not contain the generator)
          # Test the generator. Its project must have the correct format, and
          # its build and tests must have no errors.
          new-project = pkgs.callPackage ./nix/new-project/test.nix {
            new-project = pkgs.callPackage ./nix/new-project { template = self.outPath; };
            treefmtWrapper = treefmtFor.${system}.config.build.wrapper;
          };
          # template-only:end
        }
      );

      # `nix fmt` formats all files.
      formatter = forAllSystems (
        pkgs: treefmtFor.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );
      # template-only:begin (new projects do not contain the generator)

      # `nix run <this flake>#new -- <name> ["description"]` makes ./<name>
      # from this template and replaces all placeholders.
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
