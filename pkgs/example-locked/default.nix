# Exercises lock mode: the src carries a skills-lock.json (the project
# lock written by the upstream skills CLI); the builder reads it at
# build time and copies each in-tree skill.
{ buildAgentPlugin }:

buildAgentPlugin {
  name = "example-locked";
  src = ./src;

  manifest = {
    "$schema" = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json";
    name = "example-locked";
    description = "Example plugin whose skills come from skills-lock.json";
    license = "MIT";
  };

  meta.description = "Lock-mode example Agent Plugin";
}
