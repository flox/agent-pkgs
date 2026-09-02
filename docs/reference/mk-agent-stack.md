# `mkAgentStack`

Composes agent plugins and one harness into a runnable stack.

```nix
mkAgentStack {
  name = "my-stack";
  harness = "claude";
  plugins = [ agent-plugin-foo agent-plugin-bar ];
}
```

Building that produces `bin/my-stack`. Running it starts the agent
with every skill in the stack wired in.

## Arguments

| Argument | Default | Meaning |
| ----------------- | -------- | ------- |
| `name` | required | Stack name, and the launcher's name. |
| `harness` | required | The agent to run. See below. |
| `plugins` | `[ ]` | Packages built by `buildAgentPlugin`. |
| `audit.tools` | defaults | Packages put on PATH by the audit script. |
| `audit.threshold` | `null` | Score below which the audit script fails. |

## The harness

A stack runs exactly one agent. Three ways to name it:

| Form | Example | Behaviour |
| ------- | ------- | --------- |
| String | `harness = "claude";` | Resolved from the consumer's PATH at run time. |
| Binary path (string) | `harness = "${claude-code}/bin/claude";` | Pinned; the launcher puts that directory first on PATH. |
| Package | `harness = claude-code;` | Pinned, using `meta.mainProgram` for the agent name. |

The agent is identified by the binary's basename, matched against the
agents `flox-agent launch` supports: `agent-deck`, `claude`, `codex`,
`opencode`, `pi`. There is no table mapping package names to agent
names.

A package without `meta.mainProgram` is rejected: pass the binary
path instead. Reading the package's `bin/` during evaluation would
force it to build, which the repo does not do.

For several agents over the same plugins, build several stacks and
install them into one environment.

## Outputs

| Output | Contents |
| ------- | -------- |
| `out` | `share/agent-plugins/<plugin>/` for each plugin, plus `bin/<name>`. |
| `audit` | `bin/<name>-audit`. |

The stack carries no per-harness directories. Adapting plugins to
whatever the agent expects happens at launch, in `flox-agent launch`,
so a stack does not need rebuilding when that wiring changes.

## What fails to evaluate

An invalid stack never builds:

- no `harness`
- a harness whose binary is not an agent flox-agent can launch
- a `plugins` entry that did not come from `buildAgentPlugin`
- two plugins with the same name
- a harness package without `meta.mainProgram`
- a `harness` that is a Nix path literal, a list, or a number rather than
  a name, a binary path written as a string, or a package

## Stability

This is a public API. Nix users write it into their own repositories.
Argument names and meanings, and the output layout, do not change
without a deprecation period. New optional arguments may be added.
