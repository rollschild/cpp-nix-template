# The generator for `nix run <this flake>#new -- <name>`. As a package, it uses
# the tool versions in flake.lock, not the tools of the host, and shellcheck
# examines it at build time. `template` is the source of the template (the
# `self` of the flake).
{
  writeShellApplication,
  coreutils,
  findutils,
  git,
  gnused,
  perl,
  template,
}:

writeShellApplication {
  name = "new-project";
  runtimeInputs = [
    coreutils
    findutils
    git
    gnused
    perl
  ];
  # `nix fmt` and `nix develop` use the Nix of the host. It stays on PATH after
  # these tools.
  runtimeEnv.TEMPLATE = template;
  text = builtins.readFile ./new-project.sh;
}
