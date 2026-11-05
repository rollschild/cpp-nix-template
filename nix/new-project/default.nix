# The generator behind `nix run <this flake>#new -- <name>`. Packaging it here
# pins its tools to flake.lock (not whatever the host has) and runs shellcheck
# when it is built. `template` is the template's source (the flake's `self`).
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
  # `nix fmt` and `nix develop` use the host's Nix, still on PATH after these.
  runtimeEnv.TEMPLATE = template;
  text = builtins.readFile ./new-project.sh;
}
