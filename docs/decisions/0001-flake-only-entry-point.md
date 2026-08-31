# 0001. Flake-only entry point

Date: 2026-08-28

Status: Accepted

## Context

The initial skeleton shipped two front doors with equal weight: a
`flake.nix` and a `default.nix` built on flake-compat, sharing one
nixpkgs pin. On macOS CI the non-flake door failed: flake-compat's
evaluator-level `fetchTarball` could not verify GitHub's SSL
certificate, and vendoring flake-compat only shifted the maintenance
burden. No current consumer needs the non-flake door.

## Decision

We will expose agent-pkgs through the flake only. `default.nix` and
the flake-compat dependency are removed.

## Consequences

- `+` One entry point, one pin, no evaluator-level network fetches.
- `+` CI is simpler and passes on macOS.
- `-` Non-flake Nix users must enable flakes or wait; if a concrete
  non-flake consumer appears, a new record revisits this.
