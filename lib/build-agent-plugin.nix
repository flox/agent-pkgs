# buildAgentPlugin — build one Agent Plugin into the canonical layout:
#
#   $out/share/agent-plugins/<name>/
#   ├── plugin.json
#   ├── skills/
#   └── mcp.json        # optional
#
# SKELETON (AI-633): copies a conformant tree into place. The real
# implementation (AI-634) adds the `flox-agent check-plugin` check
# phase, the import→builder call contract, the passthru schema, and
# the hook point for the runtime substitution pass (AI-640).
{ lib, stdenvNoCC }:

{ name
, src
, meta ? { }
}:

stdenvNoCC.mkDerivation {
  pname = "agent-plugin-${name}";
  version = "0";
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/agent-plugins/${name}"
    cp -R . "$out/share/agent-plugins/${name}"
    runHook postInstall
  '';

  passthru.agentPlugin = {
    inherit name;
    path = "share/agent-plugins/${name}";
  };

  # Per AI-607: plugins make no license assertion by default (the
  # attribute is simply absent); generated packages record the
  # upstream license when known.
  inherit meta;
}
