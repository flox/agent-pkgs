{
  description = "Nix package set for Agent Plugins and Agent Stacks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Only consumed by default.nix (the non-flake front door).
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-compat }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs { inherit system; }));

      # Every subdirectory of pkgs/ with a default.nix is a package.
      # `flox-agent import --out pkgs/<name>` drops packages here; no
      # central list to edit.
      pluginDirs = pkgs:
        let
          entries = builtins.readDir ./pkgs;
          hasPackage = name:
            entries.${name} == "directory"
            && builtins.pathExists (./pkgs + "/${name}/default.nix");
        in
        builtins.filter hasPackage (builtins.attrNames entries);

      mkLib = pkgs: {
        buildAgentPlugin = pkgs.callPackage ./lib/build-agent-plugin.nix { };
        mkAgentStack = pkgs.callPackage ./lib/mk-agent-stack.nix {
          buildAgentPlugin = (mkLib pkgs).buildAgentPlugin;
        };
        runtimeMappings = import ./mappings/runtimes.nix;
      };

      mkPackages = pkgs:
        let lib' = mkLib pkgs;
        in nixpkgs.lib.genAttrs (pluginDirs pkgs) (name:
          pkgs.callPackage (./pkgs + "/${name}") {
            inherit (lib') buildAgentPlugin;
          });
    in
    {
      packages = forAllSystems mkPackages;
      checks = forAllSystems mkPackages;
      lib = forAllSystems mkLib;
    };
}
