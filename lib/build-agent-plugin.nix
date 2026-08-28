# buildAgentPlugin — build one Agent Plugin into the canonical layout:
#
#   $out/share/agent-plugins/<name>/
#   ├── plugin.json
#   ├── skills/
#   └── mcp.json        # optional
#
# Skill selection, in precedence order:
#
# 1. Explicit `skills` argument (skill name -> path inside src) — what
#    `flox-agent import` generates; see docs/import-contract.md.
# 2. A `skills-lock.json` at the src root (the project lock written by
#    the upstream skills CLI): entries are read at build time and each
#    skill is copied from its in-tree skillPath. Entries whose files
#    are not inside src (external sources) fail the build — a pure
#    build cannot fetch them; resolve those with `flox-agent import`.
# 3. Passthrough: src is already a conformant plugin tree (plugin.json
#    + skills/) and is copied as-is.
#
# plugin.json rule: an upstream plugin.json in the src root wins; the
# `manifest` argument is only for sources that ship none. Passing both
# is a build error. `mcpServers` and an upstream mcp.json follow the
# same rule.
{ lib, stdenvNoCC, jq }:

{ name
, version ? "0"
, src
  # provenance: upstream URL recorded in passthru
, sourceUrl ? null
  # manifest attrset, serialized to plugin.json when src has none
, manifest ? null
  # assemble mode: skill name -> path inside src
, skills ? null
  # mcp server configs, serialized to mcp.json when src has none;
  # attrset of server name -> config (type/command/...)
, mcpServers ? null
  # flox-agent package providing `flox-agent check-plugin`; when null
  # the check phase is skipped (until the -bin package exists)
, floxAgent ? null
, meta ? { }
}:

let
  out = "share/agent-plugins/${name}";

  manifestFile =
    if manifest == null then null
    else builtins.toFile "plugin.json" (builtins.toJSON manifest);

  mcpFile =
    if mcpServers == null then null
    else builtins.toFile "mcp.json" (builtins.toJSON {
      "$schema" = "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json";
      inherit mcpServers;
    });

  copySkill = skillName: path: ''
    if [ ! -f ${lib.escapeShellArg path}/SKILL.md ]; then
      echo "buildAgentPlugin: skill '${skillName}': no SKILL.md at '${path}' in src" >&2
      exit 1
    fi
    mkdir -p "$dest/skills"
    cp -R ${lib.escapeShellArg path} "$dest/skills/${skillName}"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "agent-plugin-${name}";
  inherit version src;

  nativeBuildInputs = [ jq ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    dest="$NIX_BUILD_TOP/plugin/${name}"
    mkdir -p "$dest"

    ${if skills != null then ''
      # 1. explicit skill mapping from the import contract
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList copySkill skills)}
    '' else ''
      if [ -f skills-lock.json ]; then
        # 2. project lock written by the upstream skills CLI
        mkdir -p "$dest/skills"
        jq -r '.skills | to_entries[] | "\(.key)\t\(.value.skillPath // "")"' \
            skills-lock.json | while IFS=$'\t' read -r sname spath; do
          sdir=""
          if [ -n "$spath" ] && [ -f "$(dirname "$spath")/SKILL.md" ]; then
            sdir="$(dirname "$spath")"
          elif [ -f "skills/$sname/SKILL.md" ]; then
            sdir="skills/$sname"
          fi
          if [ -z "$sdir" ]; then
            echo "buildAgentPlugin: lock entry '$sname' is not inside src — a pure build cannot fetch external sources; generate this package with 'flox-agent import' instead" >&2
            exit 1
          fi
          cp -R "$sdir" "$dest/skills/$sname"
        done
      elif [ -f plugin.json ] && [ -d skills ]; then
        # 3. passthrough: src is already a conformant plugin tree
        cp -R . "$dest"
        chmod -R u+w "$dest"
      else
        echo "buildAgentPlugin: no skills argument, no skills-lock.json, and src is not a plugin tree" >&2
        exit 1
      fi
    ''}

    # plugin.json: upstream file wins; manifest only fills the gap
    if [ -f plugin.json ] && [ -n "${toString (manifestFile != null)}" ]; then
      echo "buildAgentPlugin: src ships plugin.json AND a manifest argument was given — drop one" >&2
      exit 1
    fi
    if [ ! -f "$dest/plugin.json" ]; then
      if [ -f plugin.json ]; then
        cp plugin.json "$dest/plugin.json"
      elif [ -n "${toString (manifestFile != null)}" ]; then
        cp ${toString manifestFile} "$dest/plugin.json"
      else
        echo "buildAgentPlugin: src ships no plugin.json and no manifest argument was given" >&2
        exit 1
      fi
    fi

    # mcp.json: same rule
    if [ -f mcp.json ] && [ -n "${toString (mcpFile != null)}" ]; then
      echo "buildAgentPlugin: src ships mcp.json AND mcpServers was given — drop one" >&2
      exit 1
    fi
    if [ ! -f "$dest/mcp.json" ]; then
      if [ -f mcp.json ]; then
        cp mcp.json "$dest/mcp.json"
      elif [ -n "${toString (mcpFile != null)}" ]; then
        cp ${toString mcpFile} "$dest/mcp.json"
      fi
    fi

    # Hook point for the runtime substitution pass (AI-640): runs on
    # the fully assembled tree, before install and checks.
    runHook postAssemble

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/agent-plugins"
    cp -R "$NIX_BUILD_TOP/plugin/${name}" "$out/${out}"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase =
    if floxAgent != null then ''
      runHook preInstallCheck
      ${lib.getExe' floxAgent "flox-agent"} check-plugin --strict "$out/${out}"
      runHook postInstallCheck
    '' else ''
      echo "buildAgentPlugin: flox-agent not provided — skipping check-plugin validation" >&2
    '';

  passthru.agentPlugin = {
    inherit name sourceUrl;
    path = out;
    specVersion =
      if manifest != null && manifest ? "$schema"
      then lib.removeSuffix "/plugin.schema.json"
        (lib.last (lib.splitString "/schemas/" manifest."$schema"))
      else null;
    skills = if skills == null then null else builtins.attrNames skills;
  };

  # Per AI-607: plugins make no license assertion by default (the
  # attribute is simply absent); generated packages record the
  # upstream license when known.
  inherit meta;
}
