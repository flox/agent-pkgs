# agent-pkgs

A Nix package set for [Agent Plugins](https://agent-plugins.org):
skills and MCP server configurations packaged as reproducible,
closure-complete Nix packages, and composed into Agent Stacks.

Packages here are generated and validated by
[`flox-agent`](https://github.com/flox/flox-agent), but the repo
builds with plain Nix — no Flox required.

## Use it

With flakes:

```sh
nix build github:flox/agent-pkgs#example-plugin
```

Without flakes:

```sh
nix-build https://github.com/flox/agent-pkgs/archive/main.tar.gz \
  -A packages.x86_64-linux.example-plugin
```

Both front doors share one nixpkgs pin (`flake.lock`).

Every package produces the canonical Agent Plugins layout:

```text
result/share/agent-plugins/<name>/
├── plugin.json
├── skills/
└── mcp.json        # optional
```

## Layout

| Path | Contents |
| ---------------------------- | -------- |
| `lib/build-agent-plugin.nix` | `buildAgentPlugin` — one plugin per upstream repo |
| `lib/mk-agent-stack.nix` | `mkAgentStack` — compose plugins into a stack |
| `pkgs/<name>/` | One package per plugin; auto-discovered, no central list |
| `mappings/runtimes.nix` | Ecosystem runtime names to nixpkgs attributes |

Add a package by dropping a directory into `pkgs/` — typically via
`flox-agent import <repo> --out pkgs/<name>`.

## Fork it

An organization using Nix (with or without Flox) can fork this repo
as an internal plugin marketplace: keep `lib/`, replace `pkgs/` with
your own set, and CI (plain GitHub Actions) builds every package on
every PR.

## License

MIT. Individual packaged plugins carry their upstream licenses,
recorded in each package's `meta`.
