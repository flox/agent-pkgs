# Handwritten example plugin. Proves the pipeline end to end and
# serves as the template for what `flox-agent import --out` generates.
{ buildAgentPlugin }:

buildAgentPlugin {
  name = "example-plugin";
  src = ./src;
  meta = {
    description = "Minimal example Agent Plugin built with buildAgentPlugin";
    homepage = "https://github.com/flox/agent-pkgs";
  };
}
