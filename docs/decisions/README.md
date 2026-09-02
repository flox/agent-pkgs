# Decision records

Significant, hard-to-reverse choices for `agent-pkgs`, recorded so
the reasoning survives the people who made it. One decision per file,
numbered in order. A record is immutable once accepted: to change a
decision, add a new record that supersedes the old one.

Format and process live in [template.md](template.md).

| # | Decision |
| ---- | -------- |
| [0001](0001-flake-only-entry-point.md) | Flake-only entry point |
| [0002](0002-optional-check-phase.md) | Optional check phase until the -bin package exists |
| [0003](0003-upstream-manifest-wins.md) | Upstream plugin.json wins; manifest argument fills the gap |
| [0004](0004-skill-selection-precedence.md) | Skill selection: explicit args, then lock file, then passthrough |
| [0005](0005-canonical-output-layout.md) | Canonical output under share/agent-plugins/ |
| [0006](0006-runtime-substitution.md) | Runtime substitution: plugin-local bin/, deterministic scope |
| [0007](0007-one-harness-per-stack.md) | One harness per stack, detected from the binary |
