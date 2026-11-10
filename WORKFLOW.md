# Workflow

All commands for this project, in the sequence that you use them.

## 0. Machine setup (one time)

- **Nix.** Add `experimental-features = nix-command flakes` to the Nix
  configuration.
- **direnv and [nix-direnv].** direnv loads the dev shell when you go into the
  project directory. nix-direnv keeps the shell in a cache until `flake.nix`,
  `flake.lock` or a `nix/*.nix` file changes. If a change causes an evaluation
  error, nix-direnv keeps the last shell that operated correctly. The Home
  Manager configuration (NixOS has the same options in `programs.direnv`):

  ```nix
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  ```

  Without direnv, use `nix develop`. It gives the same shell.
- **Editor.** The dev shell puts clangd, clang-tidy and the `nix fmt`
  formatters on `PATH`, with the versions in `flake.lock`. Start the editor
  from the project directory, so that it uses these tools. Then format-on-save
  gives the same result as CI. For CMake files, set `gersemi` as the formatter
  (conform.nvim: `cmake = { "gersemi" }`).

[nix-direnv]: https://github.com/nix-community/nix-direnv

## 1. Make a new project from the template

```bash
cd ~/projects
nix run github:rollschild/cpp-nix-template#new -- my_tool
cd my_tool
direnv allow                    # load the dev shell
cmake --workflow --preset dev   # build and test
```

The generator:

1. Asks for the name and a one-line description, if they are not on the
   command line. The name must be lower_snake_case, because it is the C++
   namespace. For an incorrect name, the generator shows a correct
   alternative. The description cannot contain `"`, `\` or `$`.
2. Shows a summary. Push Enter to make the project.
3. Copies the template to `./my_tool`, without the generator and the other
   template-only parts.
4. Writes the name and the description into the files and the file names. The
   Nix files read them from `project(...)` in `CMakeLists.txt`
   (`nix/project.nix`).
5. Writes the year and your git `user.name` into `LICENSE`.
6. Makes a git repository on the branch `main` and stages all files. Flakes
   see only the files that git tracks.
7. Runs `nix fmt`.
8. Configures the `dev` preset. This writes `build/dev/compile_commands.json`
   for clangd before you open the editor.
9. Shows a warning if a file contains a placeholder.

Notes:

- To give all values on the command line, with no prompts:
  `nix run github:rollschild/cpp-nix-template#new -- my_tool "One-line description"`.
- To use the template on this machine, replace
  `github:rollschild/cpp-nix-template` with `~/projects/cpp-nix-template`. This
  includes the uncommitted changes to tracked files.
- `github:` uses the pushed template. Nix keeps it in a cache for a maximum
  of one hour. After you push a change to the template, add `--refresh` after
  `nix run`.
- The `nix flake check` of the template tests the generator.

The generator cannot write the example code or the body of `README.md`.
Replace the example (the `greet` function) in `include/my_tool/my_tool.hpp`,
`src/my_tool.cpp`, `apps/main.cpp` and `tests/my_tool_test.cpp`. Then:

```bash
nix flake check                 # optional: all the checks that CI does
git commit -m "Initial commit from cpp-nix-template"
gh repo create my_tool --private --source . --push   # optional: starts CI and Dependabot
```

## 2. Open a project

On this machine:

```bash
cd ~/projects/myproject         # direnv loads the dev shell from the cache
git pull                        # if the remote has changes, for example a merged Dependabot PR
cmake --workflow --preset dev --fresh   # only if flake.lock changed (new compiler path)
```

A new clone, for example on a different machine:

```bash
git clone git@github.com:rollschild/myproject.git
cd myproject
direnv allow                    # load the dev shell
cmake --workflow --preset dev   # before you open the editor: this writes the compile database for clangd
```

## 3. Daily work

```bash
nvim .                          # from the project directory, after the first configure
cmake --build --preset dev      # build
ctest --preset dev              # test (to build and test: cmake --workflow --preset dev)
ctest --preset dev -R <regex>   # only the tests with a name that agrees with <regex>
./build/dev/tests/myproject_tests "<test case name>"   # one Catch2 test case, with the Catch2 output
./build/dev/apps/myproject [args]                      # the executable (Debug build)
gdb --args ./build/dev/apps/myproject [args]           # debug the executable (or nvim-dap: <leader>db, <leader>dc)
```

- Add each new `.cpp` or `.hpp` file to its target in `CMakeLists.txt`. The
  build uses only the files in these lists.
- When you save a `CMakeLists.txt` in Neovim, Neovim configures the build
  trees again. Then clangd has the correct flags.
- Run `git add` for each new file. Nix (`nix build`, `nix flake check`) sees
  only tracked files. CMake sees all files.
- For a temporary build without warnings as errors:
  `cmake --preset dev --compile-no-warning-as-error`.

## 4. Before you commit or push

```bash
cmake --workflow --preset asan  # Debug build with AddressSanitizer and UBSan
cmake --workflow --preset tidy  # clang-tidy on all files: each warning is an error
nix fmt                         # format and lint C++, CMake, Python and Nix
git add -A
nix flake check                 # the CI checks: GCC and Clang builds and tests, clang-tidy, format, lint
git commit -m "..."
git push                        # CI also runs the asan workflow in the dev shell
```

## 5. Dependencies

Where to put each type of dependency:

| Dependency | Put it in | Examples |
| --- | --- | --- |
| A library that your code links to | `buildInputs` in `nix/package.nix` | `abseil-cpp`, `boost`, `liburing` |
| A library that only the tests use | `checkInputs` in `nix/package.nix` | `catch2_3` (in the template) |
| A tool that the build runs | `nativeBuildInputs` in `nix/package.nix` | `protobuf` (for `protoc`) |
| A tool that you use, but the build does not | `packages` in `nix/shell.nix` | `hyperfine`, `valgrind`, `lldb` |
| A Python library for `scripts/` | `python3.withPackages` in `nix/shell.nix` | `ps.numpy`, `ps.matplotlib` |

Each Nix file is a function. Write the package name in **two** places: in the
argument list at the top (`{ lib, stdenv, ..., abseil-cpp }:`) and in the
list. When you save the file, direnv loads the shell again.

### Find the package and its CMake names

```bash
nix search --inputs-from . nixpkgs '^abseil'      # the attribute name, in the pinned nixpkgs of the project
find $(nix build --no-link --print-out-paths --inputs-from . 'nixpkgs#abseil-cpp^*') \
    -name '*[Cc]onfig.cmake'                       # .../lib/cmake/absl/abslConfig.cmake -> find_package(absl)
grep -ho 'add_library([^ ]*' $(find $(nix build --no-link --print-out-paths --inputs-from . \
    'nixpkgs#abseil-cpp^*') -name '*[Tt]argets.cmake') | sort -u   # the targets: absl::flat_hash_map, ...
```

### Add a C++ library (example: abseil)

1. In `nix/package.nix`, add `abseil-cpp` to the arguments and to
   `buildInputs`.
2. In `src/CMakeLists.txt`, add `find_package(absl REQUIRED)` and
   `target_link_libraries(myproject_lib PRIVATE absl::flat_hash_map)`.
3. If the public headers in `include/myproject/` use types from the library,
   use `PUBLIC`, not `PRIVATE`. Then also add `find_dependency(absl)` to
   `cmake/myproject-config.cmake.in`. This lets users of the installed package
   find the library.
4. Run `cmake --workflow --preset dev`, then `nix flake check`. The Nix build
   uses a sandbox. In the sandbox, a dependency that is not in
   `nix/package.nix` causes an error.

For a library that only the tests use, put it in `checkInputs`. Put its
`find_package` and `target_link_libraries(myproject_tests PRIVATE ...)` in
`tests/CMakeLists.txt`. CMake reads that file only if `BUILD_TESTING` is on.

### Remove a dependency

1. Remove it from the list and from the arguments in `nix/package.nix` or
   `nix/shell.nix`.
2. Remove its `find_package`, its `target_link_libraries` entry, its
   `find_dependency` line and its `#include` lines.
3. Run `cmake --workflow --preset dev --fresh`. `--fresh` removes the old
   `find_package` results from the CMake cache.
4. Run `nix flake check`.

### Versions

The pinned nixpkgs (`flake.lock`) sets all versions. `nix flake update`
changes all of them together. For a different version of one library, nixpkgs
frequently has a separate attribute, for example `boost187` and `boost`.
`nix search` shows these attributes.

### A library that is not in nixpkgs

Write a package for it in a small file in `nix/`, for example
`nix/unordered-dense.nix`:

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "unordered-dense";
  version = "4.5.0";
  src = fetchFromGitHub {
    owner = "martinus";
    repo = "unordered_dense";
    tag = "v${finalAttrs.version}";
    hash = lib.fakeHash; # replace with the hash that Nix shows at the first build
  };
  nativeBuildInputs = [
    cmake
    ninja
  ];
})
```

1. Run `git add nix/unordered-dense.nix`. Flakes see only tracked files.
2. In `nix/package.nix`, add `callPackage` to the arguments. Add
   `(callPackage ./unordered-dense.nix { })` to `buildInputs`.
3. Run `nix build`. The first build stops with `got: sha256-...`. Copy that
   value into `hash`.
4. In CMake, use it as all other packages:
   `find_package(unordered_dense REQUIRED)` and the target
   `unordered_dense::unordered_dense`.

Do not use CMake `FetchContent` for dependencies. The Nix sandbox has no
network access, so `nix build` and CI cannot download them.

## 6. Other tasks

### Python scripts

- Put helper scripts in `scripts/`, for example for data generation, analysis
  or plots. Run them in the dev shell: `python3 scripts/foo.py`. For their
  libraries, see §5.
- `nix fmt` runs ruff: lint with automatic fixes, then format.
  `nix flake check` shows an error for each problem that ruff cannot fix. The
  rules are in `ruff.toml`.
- For a script that the build runs, for example a code generator:
  1. Add `(python3.withPackages (ps: [ ... ]))` to `nativeBuildInputs` in
     `nix/package.nix`. The dev shell gets it from the package.
  2. In CMake, find it with `find_package(Python3 COMPONENTS Interpreter)`.
  3. Add `../scripts` to the `fileset` in `nix/package.nix`.

### Other commands

| Task | Command |
| --- | --- |
| Optimized build (RelWithDebInfo) with only the CMake flags, for benchmarks or disassembly | `cmake --workflow --preset release` |
| Build the Nix package | `nix build`, then `./result/bin/myproject` |
| Build and run the Nix package | `nix run . -- [args]` |
| Install the release build | `cmake --install build/release --prefix ~/.local` |
| Use the dev shell without direnv | `nix develop` |
| Update the toolchain | `nix flake update`, `cmake --workflow --preset dev --fresh`, `nix flake check`. Then commit `flake.lock`. |
| Dependabot PR (monthly) | If CI has no errors, merge it. Then `git pull` and `cmake --workflow --preset dev --fresh`. |
| Change the version | Edit `project(... VERSION x.y.z)` in `CMakeLists.txt`. Nix reads it from there. |
| Clean build | `rm -rf build/dev && cmake --workflow --preset dev` |
| Personal CMake settings (ccache, a different generator or compiler) | `CMakeUserPresets.json`. Git ignores it. It can inherit these presets. |

## 7. Problems

| What you see | Cause | What to do |
| --- | --- | --- |
| clangd: `'myproject/myproject.hpp' file not found`, `no member named 'format' in namespace 'std'` | There is no compile database. clangd reads `build/dev/compile_commands.json` (`.clangd`). Without it, clangd uses default flags: no include path, C++17. A clangd that started before the database existed keeps these flags. | Run `cmake --preset dev`. Then restart clangd: `:lsp restart clangd` in Neovim, `editor: restart language server` in Zed. |
| `error: Path 'nix/foo.nix' ... is not tracked by Git` | Flakes see only the files that git tracks. | `git add nix/foo.nix` |
| `hash mismatch ... got: sha256-...` | A new or changed `fetchFromGitHub`. | Copy the `got:` hash into `hash`. |
| CMake shows that the compiler changed, or finds a package that you removed | The CMake cache has old paths from before `nix flake update` or a dependency change. | `cmake --workflow --preset dev --fresh` |
| clang-tidy shows an error for correct code | `.clang-tidy` makes each warning an error. | Add `// NOLINT(check-name): reason` on that line. Or add `-check-name` to `Checks` in `.clang-tidy`. |
| `direnv: error .envrc is blocked` | This `.envrc` is new or changed. | `direnv allow` |
| The shell does not have a tool or a library after a change to `nix/*.nix` | direnv did not load the shell again yet. | Push Enter at the prompt, or run `direnv reload`. |
