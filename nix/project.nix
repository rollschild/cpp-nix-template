# The project name, version and description, from
# `project(<name> VERSION ... DESCRIPTION "...")` in CMakeLists.txt. That is
# the only source of these values, as Cargo.toml is for Rust flakes. No Nix
# file contains the name or the version.
let
  cmakeLists = builtins.readFile ../CMakeLists.txt;
  field = re: builtins.head (builtins.match ".*project\\([[:space:]]*${re}.*" cmakeLists);
in
{
  name = field "([A-Za-z0-9_]+)";
  version = field "[^)]*VERSION[[:space:]]+([^[:space:])]+)";
  description = field "[^)]*DESCRIPTION[[:space:]]+\"([^\"]*)\"";
}
