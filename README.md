# openclaw-federation (archived)

> **This repository is a historical snapshot.** OGP's canonical specification, implementation, and active development have moved to [**dp-pcs/ogp**](https://github.com/dp-pcs/ogp).
>
> The protocol has evolved substantially since this repo's last update (April 2026, v0.2.11). For current behavior — including identity snapshots, bidirectional health exchange, the federation lifecycle state machine, the multi-framework meta-config, and the keychain operator helpers — read the live docs in the `ogp` repo, not this one.

## Where to find current docs

| You want… | Look here |
|---|---|
| Wire protocol spec | [`dp-pcs/ogp/docs/PROTOCOL.md`](https://github.com/dp-pcs/ogp/blob/main/docs/PROTOCOL.md) |
| Architectural framing (OGP vs A2A, BGP parallel, design principles) | [`dp-pcs/ogp/docs/ARCHITECTURE.md`](https://github.com/dp-pcs/ogp/blob/main/docs/ARCHITECTURE.md) |
| Scope model and negotiation | [`dp-pcs/ogp/docs/scopes.md`](https://github.com/dp-pcs/ogp/blob/main/docs/scopes.md) |
| Agent-comms response levels | [`dp-pcs/ogp/docs/agent-comms.md`](https://github.com/dp-pcs/ogp/blob/main/docs/agent-comms.md) |
| Rendezvous and invite tokens | [`dp-pcs/ogp/docs/rendezvous.md`](https://github.com/dp-pcs/ogp/blob/main/docs/rendezvous.md) |
| Multi-framework support (OpenClaw / Hermes / standalone) | [`dp-pcs/ogp/docs/MULTI-FRAMEWORK-DESIGN.md`](https://github.com/dp-pcs/ogp/blob/main/docs/MULTI-FRAMEWORK-DESIGN.md) |
| CLI reference | [`dp-pcs/ogp/docs/CLI-REFERENCE.md`](https://github.com/dp-pcs/ogp/blob/main/docs/CLI-REFERENCE.md) |
| Install and quickstart | [`dp-pcs/ogp/README.md`](https://github.com/dp-pcs/ogp) |

## Try OGP

```bash
npm install -g @dp-pcs/ogp@latest
ogp setup
ogp start --background
ogp status
```

## What's still in this repo (frozen in time)

The files below reflect protocol design as of v0.2.11 (March/April 2026). They are preserved for historical context and may be useful for understanding earlier design decisions, but they are **not authoritative for current behavior**.

- `PROTOCOL.md` — protocol spec snapshot, v0.2.11
- `INTENTS.md` — intent catalog snapshot
- `DESIGN.md` — early architecture decisions
- `RENDEZVOUS.md` — rendezvous discovery design (early version)
- `FINDINGS.md` — development journal
- `PHASE3.md` — phase-3 planning doc
- `PLAN.md`, `BACKLOG.md` — historical planning artifacts
- `scripts/` — early reference shell scripts for calendar intents

## Why was this archived?

OGP shipped daily through April 2026. The implementation outpaced the standalone spec repo, and maintaining two sources of truth was creating drift. The repo at `dp-pcs/ogp` now holds both the implementation and the canonical specification, which keeps them aligned.

If a second independent implementation of OGP appears in the future — for example, a Python-native daemon — a vendor-neutral spec repository may be revived under a new name. Until then, the implementation defines the spec.

## Read the build story

The OGP design and build is documented in long-form at [Trilogy AI Center of Excellence](https://trilogyai.substack.com). Notable entries:

- *Delegated Authority: When Your Agent Decides Without You*
- *The Project Layer: Shared Workspaces Across Independent Agents*
- *Five Layers of No: How OGP's Doorman Actually Works*
- *Breaking Up with OpenClaw: How OGP Learned to Play with Others*
- *Microsoft Just Unified the Agent Stack, And Forgot the Personal Layer*
