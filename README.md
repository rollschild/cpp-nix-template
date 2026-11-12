# myproject

C++23 project template with CMake presets and a Nix flake.

<!-- template-only:begin -->
**This repository is a template.** To make a project from it, run
`nix run github:rollschild/cpp-nix-template#new -- <name>`. The generator asks
for a description, writes the name and the description into all files, and
configures the project. For more information, see [WORKFLOW.md](WORKFLOW.md)
§1. The generator is in `nix/new-project/`, and `nix flake check` tests it.
New projects do not contain it.

<!-- template-only:end -->
This project contains a C++23 library, a command-line executable and GoogleTest
tests. CMake presets build it. A Nix flake supplies the dev shell and the
package. Python helper scripts go in `scripts/`. `nix flake check` does the
same build, test, format and lint checks as CI.

## First steps

```bash
direnv allow                    # load the dev shell
cmake --workflow --preset dev   # configure, build and test
```

**[WORKFLOW.md](WORKFLOW.md) has all commands**, in the sequence that you use
them.

## Layout

```
.
├── flake.nix                 # inputs and outputs (the logic is in nix/)
├── flake.lock                # pinned nixpkgs (nixos-unstable) and treefmt-nix
├── nix/
│   ├── package.nix           # the derivation, in nixpkgs style (callPackage)
│   ├── project.nix           # name, version and description from CMakeLists.txt
│   ├── shell.nix             # dev shell: package dependencies, clangd, formatters, Python, gdb
│   └── treefmt.nix           # `nix fmt`: clang-format, gersemi, ruff, nixfmt
├── CMakeLists.txt            # project(VERSION), subdirectories, install rules
├── CMakePresets.json         # presets dev, asan, tidy, release, and their workflows
├── cmake/                    # warning flags, install and export rules, package configuration
├── include/myproject/        # public headers (installed, FILE_SET HEADERS)
├── src/                      # library sources and private headers
├── apps/                     # executables
├── tests/                    # GoogleTest tests (CTest has each TEST)
├── ruff.toml                 # Python lint and format rules
├── WORKFLOW.md               # all commands, in sequence
├── .envrc                    # direnv: `use flake`
├── .clangd                   # clangd reads build/dev/compile_commands.json
├── .clang-format  .clang-tidy  .editorconfig
└── .github/                  # CI (`nix flake check` and an ASan run), Dependabot
```

The layout is the Pitchfork Layout with separate headers: public headers in
`include/`, private headers in `src/`. Executables are in `apps/`. Each preset
has its own build tree, `build/<preset>`.

## Design notes

- **One source for each fact.** The dependencies are in `nix/package.nix`, and
  the dev shell gets them through `inputsFrom`. The name, version and
  description are in `project(...)` in `CMakeLists.txt`, and
  `nix/project.nix` reads them from there. Only `flake.nix` has a copy of the
  description, because Nix must have a literal string there.
- **The nixpkgs CMake hook does the build.** There are no custom phases. The
  hook sets the compiler, `-DCMAKE_BUILD_TYPE=Release` and `-GNinja`. It runs
  `ctest` if `doCheck` is set. If not, it sets `-DBUILD_TESTING=OFF`. Then it
  runs `install`.
- **`lib.fileset` filters the source.** A change to the docs, scripts or Nix
  files does not rebuild the package.
- **The development flags stay in this project.** Each target gets its
  warnings as `PRIVATE` flags (`myproject_enable_warnings`). `-Werror` comes
  from the CMake variable `CMAKE_COMPILE_WARNING_AS_ERROR`, which the presets
  and the Nix package set. Only the `asan` preset has sanitizers.
- **Two compilers and clang-tidy.** `nix flake check` builds and tests with
  the default stdenv (GCC on Linux) and with `clangStdenv`. It also runs
  clang-tidy on all files, and each warning is an error. CI also runs the
  `asan` workflow (ASan and UBSan).
- **Automatic updates.** nixpkgs follows `nixos-unstable`, because
  cache.nixos.org builds that branch. Each month, Dependabot opens a PR that
  updates `flake.lock` and the GitHub Actions. CI tests the PR.
- **No compiler-wrapper hardening in the dev shell.** The nixpkgs compiler
  wrapper adds hardening flags that CMake and `compile_commands.json` do not
  show:
  - `-fno-strict-overflow` makes signed overflow wrap, so UBSan cannot find
    it.
  - Fortify adds `-O2`, which optimizes Debug builds.
  - `-fzero-call-used-regs`, the stack protector and stack-clash probes add
    instructions to all functions.

  The dev shell removes these flags, so dev builds use only the CMake flags.
  The Nix package keeps the full nixpkgs hardening, because you ship it.
- **gersemi formats CMake.** gersemi has regular releases and knows the
  current CMake syntax. cmake-format has had no release since 2020.
- **No C++20 module scan.** The project does not use modules. The scan adds
  GCC flags that clangd and clang-tidy show as errors.
- **No `shellHook`.** The dev shell does not change your shell or your prompt.
