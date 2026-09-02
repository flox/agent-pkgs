# A stack over the example plugins. Demonstrates the composition API
# and gives CI something end to end to build.
{ mkAgentStack, example-plugin, example-runtimes }:

mkAgentStack {
  name = "example-stack";
  harness = "claude";
  plugins = [ example-plugin example-runtimes ];
}
