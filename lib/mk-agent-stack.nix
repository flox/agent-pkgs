# mkAgentStack — compose plugins into one Agent Stack.
#
# SKELETON (AI-633): symlink-joins the plugins' share/agent-plugins
# trees. The real composition work (harness wiring, conflict rules,
# stack metadata) lands with the Composition project.
{ lib, symlinkJoin, buildAgentPlugin }:

{ name
, plugins
}:

symlinkJoin {
  name = "agent-stack-${name}";
  paths = plugins;
  passthru.agentStack = {
    inherit name;
    plugins = map (p: p.passthru.agentPlugin.name or p.name) plugins;
  };
}
