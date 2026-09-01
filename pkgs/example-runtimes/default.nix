# Exercises the runtime substitution pass: a python script, a node
# script, and an mcp server command, all resolved through
# mappings/runtimes.nix into the plugin-local bin/.
{ buildAgentPlugin }:

buildAgentPlugin {
  name = "example-runtimes";
  src = ./src;

  manifest = {
    "$schema" = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json";
    name = "example-runtimes";
    description = "Example plugin whose scripts need python and node";
    license = "MIT";
  };

  skills = {
    greet = "skills/greet";
  };

  mcpServers = {
    hello = {
      type = "stdio";
      command = "python3";
      args = [ "-m" "hello_server" ];
    };
  };

  meta.description = "Substitution-pass example Agent Plugin";
}
