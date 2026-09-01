# mkAgentStack — compose plugins and one harness into a runnable stack.
#
#   $out/share/agent-plugins/<plugin>/   the neutral spec layout
#   $out/bin/<name>                      launcher (added in task 2)
#   $audit/bin/<name>-audit              audit runner (added in task 4)
#
# A stack runs exactly one agent. Several agents means several stacks
# installed into one environment. All harness adaptation happens at
# launch time in `flox-agent launch`, so nothing here is per-harness.
{ lib
, stdenvNoCC
, runtimeShell
}:

{ name
  # "claude" (resolved from PATH), a path, or a package
, harness ? null
, plugins ? [ ]
, audit ? { }
}:

let
  # Mirrors the adapter registry in flox-agent internal/launch.
  knownAdapters = [ "agent-deck" "claude" "codex" "opencode" "pi" ];

  # Resolve the harness to an adapter name plus, when the harness was
  # pinned, the bin directory to prepend to PATH. meta.mainProgram is
  # the only package-side source: listing the package's bin/ would
  # force it to build during evaluation.
  harnessInfo =
    if harness == null then
      throw ''
        mkAgentStack: stack '${name}' has no harness.
        A stack runs exactly one agent:
          harness = "claude";      # resolved from the consumer's PATH
          harness = claude-code;   # pinned, with its own runtime
      ''
    else if lib.isDerivation harness then
      {
        adapter = harness.meta.mainProgram or (throw ''
          mkAgentStack: harness package has no meta.mainProgram, so the
          agent it provides cannot be named. Pass the binary instead:
            harness = "''${pkgs.claude-code}/bin/claude";
        '');
        pinDir = "${harness}/bin";
      }
    else if builtins.isString harness && lib.hasInfix "/" harness then
      { adapter = baseNameOf harness; pinDir = dirOf harness; }
    else if builtins.isString harness then
      { adapter = harness; pinDir = null; }
    else
      throw "mkAgentStack: harness must be a string, a path, or a package";

  adapter =
    if lib.elem harnessInfo.adapter knownAdapters then harnessInfo.adapter
    else throw ''
      mkAgentStack: '${harnessInfo.adapter}' is not an agent flox-agent
      can launch. Known agents: ${lib.concatStringsSep ", " knownAdapters}
    '';

  pluginOf = p:
    p.passthru.agentPlugin or (throw ''
      mkAgentStack: '${p.pname or p.name or "<unnamed>"}' is not an agent
      plugin. Every entry in `plugins` must come from buildAgentPlugin.
    '');

  pluginNames = map (p: (pluginOf p).name) plugins;

  duplicates = lib.unique
    (lib.filter (n: lib.count (m: m == n) pluginNames > 1) pluginNames);

  checkedPlugins =
    if duplicates == [ ] then plugins
    else throw ''
      mkAgentStack: duplicate plugin names: ${
        lib.concatStringsSep ", " duplicates
      }.
      Each plugin in a stack must have a unique name.
    '';

  copyPlugin = p:
    let ap = pluginOf p; in
    ''
      cp -R ${p}/${ap.path} "$out/share/agent-plugins/${ap.name}"
    '';
in
stdenvNoCC.mkDerivation {
  pname = "agent-stack-${name}";
  version = "0";
  outputs = [ "out" "audit" ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/agent-plugins" "$out/bin" "$audit/bin"
    ${lib.concatMapStringsSep "\n" copyPlugin checkedPlugins}

    runHook postInstall
  '';

  passthru.agentStack = {
    inherit name adapter harness;
    plugins = pluginNames;
  };

  meta = {
    description = "Agent stack ${name} (${adapter})";
    mainProgram = name;
  };
}
