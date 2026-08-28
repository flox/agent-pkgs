# Exercises assemble mode: the src is an "upstream repo" in its own
# layout, skills are mapped explicitly and the manifest is generated —
# the exact call shape `flox-agent import` emits (docs/import-contract.md).
{ buildAgentPlugin }:

buildAgentPlugin {
  name = "example-assembled";
  src = ./src;
  sourceUrl = "https://github.com/flox/agent-pkgs";

  manifest = {
    "$schema" = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json";
    name = "example-assembled";
    description = "Example plugin assembled from a non-plugin source layout";
    license = "MIT";
  };

  skills = {
    greet = "docs/agent-skills/greeting";
  };

  mcpServers = {
    echo = {
      type = "stdio";
      command = "echo-server";
    };
  };

  meta.description = "Assemble-mode example Agent Plugin";
}
