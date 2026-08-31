# Runtime name-mapping table: ecosystem interpreter names as they
# appear in skills (shebangs, mcp.json commands) mapped to nixpkgs
# attribute names. Consumed by the substitution pass in
# buildAgentPlugin (AI-640, which fills this table).
#
# Unmapped names must fail the build with a message pointing here.
{
  # "node" = "nodejs";
  # "python" = "python3";
}
