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
  # From mappings/audit-tools.nix; see that file for why it may be empty.
, defaultAuditTools ? [ ]
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
      throw ''
        mkAgentStack: harness must be the agent's name, a path to its
        binary written as a string, or a package. A Nix path literal such
        as ./result/bin/claude is not accepted: it would copy that one
        file into the store without the rest of its package.
      '';

  adapter =
    if lib.elem harnessInfo.adapter knownAdapters then harnessInfo.adapter
    else throw ''
      mkAgentStack: '${harnessInfo.adapter}' is not an agent flox-agent
      can launch. Known agents: ${lib.concatStringsSep ", " knownAdapters}
    '';

  # Until AI-635 publishes the -bin package, the launcher resolves
  # flox-agent at run time. When it lands, agent-pkgs binds the store
  # path here and the override becomes a development escape hatch.
  floxAgentBin = ''"''${FLOX_AGENT_BIN:-flox-agent}"'';

  # builtins.placeholder gives this output's final store path, so the
  # script can name its own share directory without any substitution.
  launcherText = ''
    #!${runtimeShell}
    set -eu
  ''
  + lib.optionalString (harnessInfo.pinDir != null) ''
    export PATH="${harnessInfo.pinDir}:$PATH"
  ''
  + ''
    exec ${floxAgentBin} \
      --dir "${builtins.placeholder "out"}/share" \
      launch ${adapter} -- "$@"
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

  auditTools = audit.tools or defaultAuditTools;
  auditThreshold = audit.threshold or null;
  auditToolPath = lib.makeBinPath auditTools;

  auditText = ''
    #!${runtimeShell}
    set -eu
  ''
  + lib.optionalString (auditTools != [ ]) ''
    export PATH="${auditToolPath}:$PATH"
  ''
  + ''
    status=0
    stack_dir="${builtins.placeholder "out"}/share/agent-plugins"
    for skill in "$stack_dir"/*/skills/*/; do
      [ -f "$skill/SKILL.md" ] || continue
      echo "==> $skill"
      ${floxAgentBin} audit "$skill" --kind skill${
        lib.optionalString (auditThreshold != null)
          " --threshold ${toString auditThreshold}"
      } || status=1
    done
    exit $status
  '';
in
stdenvNoCC.mkDerivation {
  pname = "agent-stack-${name}";
  version = "0";
  outputs = [ "out" "audit" ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # Written to a file by the builder, so no shell quoting of the
  # script body is involved.
  inherit launcherText auditText;
  passAsFile = [ "launcherText" "auditText" ];

  # A stack composes plugins; it never rewrites their content.
  # buildAgentPlugin already resolved every interpreter to an absolute
  # store path and fails the build if any executable still carries a
  # /usr/bin/env shebang, so patching here would be a no-op at best and
  # a corruption of pinned paths at worst. Plugin files are also copied
  # read-only out of the store, which patchShebangs could not write to.
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/agent-plugins" "$out/bin" "$audit/bin"
    ${lib.concatMapStringsSep "\n" copyPlugin checkedPlugins}
    install -Dm755 "$launcherTextPath" "$out/bin/${name}"
    install -Dm755 "$auditTextPath" "$audit/bin/${name}-audit"

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
