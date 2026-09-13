# myproject

A C++23 project template: a library, a command-line executable and Catch2 tests,
built with CMake presets, packaged and developed with a Nix flake. Daily work is
four commands, and `nix flake check` runs the exact same build, tests and
formatting check that CI runs.

## Layout

```
.
├── flake.nix                 # inputs + outputs; the real logic lives in nix/
├── flake.lock                # pinned nixpkgs (nixos-unstable) and treefmt-nix
├── nix/
│   ├── package.nix           # the derivation, nixpkgs-style, callPackage'd
│   ├── shell.nix             # dev shell = package deps (inputsFrom) + editor tools
│   └── treefmt.nix           # `nix fmt`: clang-format, cmake-format, nixfmt
├── CMakeLists.txt            # project(), options, subdirectories, install rules
├── CMakePresets.json         # dev / asan / tidy / release presets + workflows
├── cmake/                    # CMake modules: warnings, sanitizers, install/export
├── include/myproject/        # public headers (installed, FILE_SET HEADERS)
├── src/                      # library sources and private headers
├── apps/                     # executables
├── tests/                    # Catch2 tests, each TEST_CASE registered with CTest
├── .envrc                    # direnv: `use flake`
├── .clangd                   # clangd reads build/dev/compile_commands.json
├── .clang-format  .clang-tidy  .editorconfig
├── .github/workflows/ci.yml  # runs `nix flake check`
└── rename.sh                 # one-shot rename of the template, deletes itself
```

The layout follows the Pitchfork Layout with separate header placement
(`include/` public, `src/` private) and uses `apps/` for executables, as in the
Modern CMake book. Every preset configures into `build/<preset>`, so the
Debug, sanitizer and release trees never collide.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- direnv with nix-direnv, strongly recommended. On NixOS:

  ```nix
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  ```

  nix-direnv caches the shell and registers it as a Nix GC root, so
  `nix-collect-garbage` can never delete the compiler that CMake has cached
  absolute paths to. Without direnv, `nix develop` gives the same shell; add
  `--profile .devshell` once to get the same GC-root protection.

## Start a new project

```bash
# Option A: the Nix way (copies tracked files only, no .git)
mkdir my_tool && cd my_tool
nix flake init -t ~/projects/cpp-nix-template

# Option B: clone and detach
git clone ~/projects/cpp-nix-template my_tool && cd my_tool && rm -rf .git

bash rename.sh my_tool          # renames targets, namespace, headers, files
git init && git add -A          # flakes only see tracked files
direnv allow                    # loads the dev shell on every `cd` from now on
cmake --workflow --preset dev   # configure + build + test in one go
```

Then edit `LICENSE`, `HOMEPAGE_URL` in `CMakeLists.txt` and `meta` in
`nix/package.nix`. Run the script through `bash` because `nix flake init` copies
files without their executable bit.

## Daily commands

| Task                              | Command                                                    |
| --------------------------------- | ---------------------------------------------------------- |
| Enter the dev shell               | automatic with direnv, otherwise `nix develop`             |
| Configure + build + test (Debug)  | `cmake --workflow --preset dev`                            |
| Build only                        | `cmake --build --preset dev`                               |
| Run the tests                     | `ctest --preset dev`                                       |
| Run one Catch2 test case          | `./build/dev/tests/myproject_tests "greet formats the name"` |
| Run the executable (Debug build)  | `./build/dev/apps/myproject [name]`                        |
| Debug it                          | `gdb --args ./build/dev/apps/myproject`                    |
| Address + UB sanitizers           | `cmake --workflow --preset asan`                           |
| clang-tidy on every file          | `cmake --workflow --preset tidy`                           |
| Optimised build (RelWithDebInfo)  | `cmake --workflow --preset release`                        |
| Format all C++, CMake and Nix     | `nix fmt`                                                  |
| Everything CI checks, locally     | `nix flake check`                                          |
| Build the Nix package             | `nix build` then `./result/bin/myproject`                  |
| Run the package without a checkout| `nix run . -- Nix`                                         |
| Install to a prefix               | `cmake --install build/release --prefix ~/.local`          |
| Update pinned nixpkgs             | `nix flake update`                                         |

Personal overrides (another generator, ccache, a different compiler) go in
`CMakeUserPresets.json`, which is git-ignored and inherits from these presets.

## Adding a dependency

1. Add the nixpkgs attribute to `buildInputs` in `nix/package.nix`
   (`checkInputs` if only the tests need it). direnv reloads the shell
   automatically because `.envrc` watches that file.
2. `find_package(Foo REQUIRED)` and `target_link_libraries(myproject_lib PUBLIC Foo::Foo)`
   in `src/CMakeLists.txt`. Use `PRIVATE` if the dependency does not appear in
   your public headers.
3. For every `PUBLIC` dependency add `find_dependency(Foo)` to
   `cmake/myproject-config.cmake.in` so consumers of the installed package get
   it transitively.

## Design notes

- **One source of truth for dependencies.** `nix/package.nix` lists them; the
  dev shell inherits them through `inputsFrom`. The shell can never drift from
  the build.
- **The nixpkgs CMake hook does the work.** No hand-written phases. It passes
  the compiler, `-DCMAKE_BUILD_TYPE=Release`, `-GNinja` and
  `-DBUILD_TESTING=OFF` unless `doCheck` is set, then runs `ctest` and `install`.
- **`lib.fileset` source filtering.** Editing this README, the flake or the
  presets does not invalidate the Nix build.
- **nixpkgs is pinned to `nixos-unstable`**, which cache.nixos.org builds.
  `master` is not cached and would compile toolchains locally.
- **Dev flags never leak.** Warnings-as-errors and sanitizers are options that
  default to OFF for anyone consuming this as a subdirectory, and are switched
  ON by the presets and by `nix/package.nix`.
- **Nothing is global in CMake.** Every flag, include path and feature is
  attached to a target; consumers link `myproject::myproject`.
- **`fortify` hardening is disabled only in the dev shell.** The nixpkgs
  compiler wrapper injects `-D_FORTIFY_SOURCE`, which glibc rejects at `-O0`.
  The Release package build keeps every hardening flag.
- **No `shellHook` tricks.** With direnv, your own shell and prompt stay
  exactly as configured; nothing runs `exec zsh` or a hidden `cmake` for you.
- **C++20 module scanning is off** because the project does not use modules,
  and scanning injects GCC-only flags that clangd and clang-tidy reject.
