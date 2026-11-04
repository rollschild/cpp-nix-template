# Workflow

Every command for this project, in the order you use them: one-time machine
setup, starting a new project from the template, opening an existing project,
the daily loop, checks before committing, and occasional tasks.

## 0. One-time machine setup

- **Nix** with flakes enabled (`experimental-features = nix-command flakes`).
- **direnv + [nix-direnv]** load the dev shell when you `cd` into a project.
  nix-direnv caches the evaluated shell (re-evaluated only when `flake.nix`,
  `flake.lock` or `nix/*.nix` change), keeps it as a GC root, and falls back
  to the last working shell if an edit breaks evaluation. With Home Manager
  (NixOS has the same options under `programs.direnv`):

  ```nix
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  ```

  Without direnv, `nix develop` gives the same shell.
- **Editor.** The dev shell puts clangd, clang-tidy and every formatter
  `nix fmt` uses on `PATH`, pinned by `flake.lock`. Start the editor from the
  project directory (direnv loads the shell) and format-on-save produces
  exactly what CI checks. For CMake, configure the editor to use `gersemi`
  (conform.nvim: `cmake = { "gersemi" }`).

[nix-direnv]: https://github.com/nix-community/nix-direnv

## 1. Start a new project from the template

```bash
cd ~/projects
nix flake new -t ~/projects/cpp-nix-template my_tool   # or: -t github:rollschild/cpp-nix-template
cd my_tool
bash rename.sh                  # asks for a description, fills in every placeholder, git init + add, nix fmt
direnv allow                    # builds and loads the dev shell (slow once, then cached)
cmake --workflow --preset dev   # configure + build + test: confirms everything works
```

- `my_tool` stands for the new project's name. It must be lower_snake_case
  because it becomes the C++ namespace. `rename.sh` takes it from the
  directory name, or pass it explicitly: `bash rename.sh my_tool`. If neither
  is valid (e.g. the directory is `my-tool`), it asks for a name, suggesting a
  converted one (`my_tool`) that Enter accepts.
- `rename.sh` then asks for a one-line description (no `"`, `\` or `$`), shows
  a summary, and on Enter fills in every placeholder: the name (namespace,
  CMake targets, file names, Nix package), the description (`CMakeLists.txt`,
  `nix/package.nix`, `flake.nix`, `README.md`), and the LICENSE year and
  holder (your git `user.name`). It removes the parts that only make sense in
  the template (the flake's `templates` output, the template note in the
  README), starts git on `main` (the branch CI runs on), reformats (a name of
  different length can change line wrapping), stages everything (flakes only
  see files tracked by git), warns if any placeholder is left, and deletes
  itself.
- Without prompts (e.g. from a script): `bash rename.sh my_tool "One-line description"`.
- Run it through `bash`: `nix flake new` drops the executable bit.
- Alternative to `nix flake new`:
  `git clone ~/projects/cpp-nix-template my_tool && rm -rf my_tool/.git`.
  `git clone` copies only committed files (`nix flake new` also copies
  uncommitted edits to tracked files), so commit template changes first.

What `rename.sh` cannot fill in: the template's example code (a `greet`
function in `include/my_tool/my_tool.hpp`, `src/my_tool.cpp`, `apps/main.cpp`
and `tests/my_tool_test.cpp`; it keeps the build and tests green until you
replace it) and the body of `README.md`. Then:

```bash
nix flake check                 # optional: everything CI will check
git commit -m "Initial commit from cpp-nix-template"
gh repo create my_tool --private --source . --push   # optional: turns on CI and Dependabot
```

## 2. Open an existing project

Already on this machine:

```bash
cd ~/projects/myproject         # direnv loads the cached dev shell
git pull                        # if anything changed upstream (e.g. a merged Dependabot PR)
cmake --workflow --preset dev --fresh   # only if flake.lock changed: new compiler path
```

Fresh clone (another machine, or from GitHub):

```bash
git clone git@github.com:rollschild/myproject.git
cd myproject
direnv allow                    # once per clone
cmake --workflow --preset dev
```

## 3. Daily loop

```bash
nvim .                          # launch from the project dir so clangd and formatters come from the dev shell
cmake --build --preset dev      # build
ctest --preset dev              # test (or both at once: cmake --workflow --preset dev)
ctest --preset dev -R <regex>   # only the tests whose names match
./build/dev/tests/myproject_tests "<test case name>"   # one Catch2 test case, with Catch2's own output
./build/dev/apps/myproject [args]                      # run the executable (Debug build)
gdb --args ./build/dev/apps/myproject [args]           # debug it (or nvim-dap: <leader>db, <leader>dc)
```

- New `.cpp`/`.hpp` files must be listed in their target's `CMakeLists.txt`
  (sources are not globbed). Saving a `CMakeLists.txt` in Neovim re-runs
  configure for existing build trees, so clangd stays current.
- `git add` new files: Nix (`nix build`, `nix flake check`) only sees tracked
  files. CMake builds see them regardless.
- To get past `-Werror` while experimenting:
  `cmake --preset dev --compile-no-warning-as-error`.

## 4. Before committing or pushing

```bash
cmake --workflow --preset asan  # Debug + AddressSanitizer + UBSan
cmake --workflow --preset tidy  # clang-tidy on every file; does not fail on warnings, so read its output
nix fmt                         # format and lint C++, CMake, Python and Nix
git add -A
nix flake check                 # what CI runs: GCC + Clang builds and tests, formatting and lint
git commit -m "..."
git push                        # CI also runs the asan workflow in the dev shell
```

## 5. Occasional tasks

### Add a C++ dependency

1. Add the nixpkgs attribute to `buildInputs` in `nix/package.nix`
   (`checkInputs` if only the tests need it). direnv reloads the shell.
2. `find_package(Foo REQUIRED)` and
   `target_link_libraries(myproject_lib PUBLIC Foo::Foo)` in
   `src/CMakeLists.txt`. Use `PRIVATE` if `Foo` does not appear in your public
   headers.
3. For every `PUBLIC` dependency, add `find_dependency(Foo)` to
   `cmake/myproject-config.cmake.in`, so consumers of the installed package
   get it transitively.
4. `cmake --workflow --preset dev`

### Python scripts

- Put helper scripts (data generation, analysis, plotting) in `scripts/` and
  run them in the dev shell: `python3 scripts/foo.py`.
- Libraries come from nixpkgs: add them to `python3.withPackages` in
  `nix/shell.nix`, e.g. `(ps: [ ps.numpy ps.matplotlib ])`.
- `nix fmt` runs ruff (lint with autofix, then format) and `nix flake check`
  fails on what it cannot fix. The rules are in `ruff.toml`.
- Scripts run by the build (code generators): put
  `(python3.withPackages (ps: [ ... ]))` in `nativeBuildInputs` in
  `nix/package.nix` instead, call it from CMake through
  `find_package(Python3 COMPONENTS Interpreter)`, and add `../scripts` to the
  `fileset` there. The dev shell inherits it.

### Everything else

| Task | Commands |
| --- | --- |
| Optimised build (RelWithDebInfo) | `cmake --workflow --preset release` |
| Build the Nix package | `nix build`, then `./result/bin/myproject` |
| Run the package without a checkout | `nix run . -- [args]` |
| Install to a prefix | `cmake --install build/release --prefix ~/.local` |
| Enter the dev shell without direnv | `nix develop` |
| Update the toolchain yourself | `nix flake update`, `cmake --workflow --preset dev --fresh`, `nix flake check`, commit `flake.lock` |
| Dependabot PR (monthly) | merge if CI is green, then `git pull` and `cmake --workflow --preset dev --fresh` |
| Bump the version | edit `project(... VERSION x.y.z)` in `CMakeLists.txt`; Nix reads it from there |
| Clean rebuild | `rm -rf build/dev && cmake --workflow --preset dev` |
| Personal CMake overrides (ccache, another generator or compiler) | `CMakeUserPresets.json`, git-ignored, can inherit these presets |
