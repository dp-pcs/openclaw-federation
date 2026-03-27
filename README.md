# openclaw-federation

Protocol design, documentation, and reference scripts for **OGP — the Open Gateway Protocol**.

OGP is a vendor-neutral federation protocol that lets two AI gateway systems, owned by different people or organizations, exchange structured agent messages with explicit trust, scoped permissions, and controlled information boundaries — without either party acting as a relay or sharing credentials.

> The standalone implementation lives at [dp-pcs/ogp](https://github.com/dp-pcs/ogp).

---

## What's In This Repo

| Path | Contents |
|---|---|
| `PROTOCOL.md` | Full protocol specification — identity, handshake, intent format, signature scheme, scope negotiation |
| `INTENTS.md` | Standard intents specification (message, task-request, status-update, agent-comms) |
| `DESIGN.md` | Architecture decisions and rationale |
| `FINDINGS.md` | Development journal — lessons learned, bugs found and fixed, design decisions |
| `PHASE3.md` | Phase 3 spec — intent taxonomy, handler registry, rate limiting, calendar demo |
| `scripts/` | Reference shell scripts for calendar-read/write intents (Google Calendar + Apple Calendar) |
| `BACKLOG.md` | Known gaps and planned work |

---

## The Short Version

Every OGP gateway publishes a federation card at `/.well-known/ogp` — a signed JSON document containing the gateway's public key, display name, and supported capabilities.

To federate, Gateway A sends a signed request to Gateway B. A human on Gateway B's side approves (choosing one-way or two-way trust). Both sides store each other's public keys. Every subsequent intent message is signed by the sender and verified by the receiver.

The gateway is the trust boundary. Agents never leave their own gateway. The gateway controls what crosses organizational lines.

---

## How OGP Relates to A2A

A2A (Google's Agent-to-Agent protocol) handles agent-to-agent conversation semantics — structured requests, typed responses, task delegation between agents inside enterprise platforms.

OGP operates at a lower layer. It federates the gateways that agents sit behind. Without OGP, your agents stay inside your gateway. With OGP, gateways establish bilateral trust and agents can coordinate across that trust boundary.

They're sequential, not competing. OGP is the handshake. A2A is the conversation.

---

## Protocol Basics

**Cryptographic identity:** Ed25519 keypairs generated per gateway on first boot. Public key published at `/.well-known/ogp`.

**Trust establishment:** Bilateral approval required. Both sides must agree. Either side can revoke.

**Scope negotiation (v0.2.0):** Per-peer scope grants control which intents each peer can access, with rate limits and topic restrictions. Three-layer model: capabilities → negotiation → runtime enforcement.

**Intent messages:** Named, typed operations (`message`, `task-request`, `agent-comms`). Signed by sender, verified by receiver. Scope enforced by the doorman at the receiving gateway.

**Information boundaries:** The receiving gateway decides what reaches its agent. The doorman layer enforces rate limits and rejects out-of-scope requests before anything reaches the main agent.

---

## Status

**Current version:** v0.2.11 (March 2026)

The protocol is implemented and working. The reference implementation (`@dp-pcs/ogp`) has been tested across two independent gateways between the US and Spain.

**v0.2.x features:**
- Scope negotiation with per-peer intent grants
- Rate limiting (sliding window, per-peer per-intent)
- Topic restrictions for agent-comms
- Async reply mechanism (callback + polling)
- Backward compatibility with v0.1 peers
- `off` response level for default-deny agent-comms
- Signed rejection responses
- Project topic auto-registration on create/approve
- Entry types vs topics terminology (v0.2.9+)
- `set-topic`, `set-default`, per-peer default response level (v0.2.10+)

Known gaps are tracked in `BACKLOG.md`. Active development is in [dp-pcs/ogp](https://github.com/dp-pcs/ogp).

---

## Related

- [dp-pcs/ogp](https://github.com/dp-pcs/ogp) — standalone OGP daemon, installable alongside any OpenClaw gateway
- [dp-pcs/openclaw](https://github.com/dp-pcs/openclaw) — OpenClaw gateway platform; integrated OGP implementation on `feature/federation` branch
- [OpenClaw](https://openclaw.ai) — the AI gateway platform that inspired and ships the reference implementation
