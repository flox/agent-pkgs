{
  description = "Nix package set for Agent Plugins and Agent Stacks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
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
      checks = forAllSystems (pkgs:
        mkPackages pkgs // {
          # Assert the canonical layout and passthru for every package.
          layout = pkgs.runCommand "check-layout"
            {
              plugins = map (p: "${p} ${p.passthru.agentPlugin.path}")
                (builtins.attrValues (mkPackages pkgs));
            } ''
            set -- $plugins
            while [ $# -ge 2 ]; do
              root="$1"; rel="$2"; shift 2
              tree="$root/$rel"
              [ -f "$tree/plugin.json" ] || { echo "missing plugin.json in $tree"; exit 1; }
              [ -d "$tree/skills" ] || { echo "missing skills/ in $tree"; exit 1; }
              found=0
              for s in "$tree/skills"/*/; do
                [ -f "$s/SKILL.md" ] || { echo "missing SKILL.md in $s"; exit 1; }
                found=1
              done
              [ "$found" = 1 ] || { echo "no skills in $tree"; exit 1; }
            done
            touch $out
          '';

          # The substitution pass (AI-640) attaches via overrideAttrs
          # on the postAssemble hook — prove that extension point works.
          override-hook =
            let
              overridden = (mkPackages pkgs).example-assembled.overrideAttrs (prev: {
                postAssemble = (prev.postAssemble or "") + ''
                  echo hooked > "$dest/HOOKED"
                '';
              });
            in
            pkgs.runCommand "check-override-hook" { } ''
              [ -f ${overridden}/share/agent-plugins/example-assembled/HOOKED ] \
                || { echo "postAssemble hook did not run"; exit 1; }
              touch $out
            '';
        });
      lib = forAllSystems mkLib;
    };
}
