# Non-flake front door, same outputs and same nixpkgs pin as the
# flake (via flake-compat reading flake.lock):
#
#   nix-build -A packages.x86_64-linux.example-plugin
#   (import ./. {}).lib.x86_64-linux.buildAgentPlugin { ... }
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  compat = lock.nodes.flake-compat.locked;
  flake-compat = fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/${compat.rev}.tar.gz";
    sha256 = compat.narHash;
  };
in
(import flake-compat { src = ./.; }).defaultNix
