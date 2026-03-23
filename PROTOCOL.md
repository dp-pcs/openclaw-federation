# OGP — Open Gateway Protocol

> *"Open Gateway Protocol. Also: Original Gangster Protocol."*

## What It Is

OGP is an open, vendor-neutral federation protocol that lets two AI gateway systems, owned by different people, exchange structured agent messages with explicit trust, scoped permissions, and rate controls — without either person acting as a relay.

In plain terms: your AI assistant can call your colleague's AI assistant directly. Neither of you has to copy-paste messages between them.

OGP is not tied to any specific AI platform. Any agentic system that implements a gateway — whether OpenClaw, a hypothetical future framework, or a custom enterprise system — can implement OGP and federate with any other OGP-compliant gateway.

---

## Why "Open"

The name is intentional. OGP is:

- **Open standard** — the protocol specification is public, not proprietary
- **Open to any gateway implementation** — OpenClaw ships the reference implementation, but the protocol belongs to no vendor
- **Open to interpretation** — "Open AI Gateway Protocol" works too, depending on context

The first implementation is OpenClaw. That shouldn't be the last.

---

## OGP vs. A2A (Google Agent2Agent)

These are frequently confused but solve different problems.

| | A2A | OGP |
|---|---|---|
| **Layer** | Agent-to-agent task delegation | Gateway-to-gateway federation |
| **Trust model** | Service-level (API keys, JWTs) | Human-level (bilateral approval) |
| **Relationship** | Stateless request/response | Persistent, approved peering |
| **Scope control** | None — any agent can call any endpoint | Explicit per-peer scope, rate limits |
| **Human in the loop** | No | Yes — approval required before first message |
| **Designed for** | Enterprise workflow automation | Personal AI assistants owned by real people |

**They're complementary, not competing.** An OGP-enabled gateway could use A2A internally to delegate tasks to specialized agents. OGP handles "can these two systems trust each other and under what terms" — A2A handles the message format once they can talk.

The cleanest analogy: A2A is like HTTP (request/response between services). OGP is like BGP (trust and policy between autonomous systems owned by different parties).

---

## The BGP Parallel

OGP borrows its trust and policy model from **BGP (Border Gateway Protocol)** — the protocol that handles routing between autonomous networks on the internet. The parallel isn't perfect (OGP doesn't compute paths or maintain route tables), but the *peering model* maps cleanly.

| BGP Concept | OGP Equivalent |
|---|---|
| Autonomous System (AS) | Individual gateway (`gw:david@trilogy.com`) |
| OPEN message | `GET /.well-known/ogp` |
| BGP session establishment | Handshake → human approval → key exchange |
| Route policy / filters | Per-peer scope (which intents are allowed) |
| MD5 session auth | Ed25519 signed messages |
| Route dampening | Per-peer rate limiting + abuse detection |
| iBGP (interior) | Agent-to-agent within one gateway |
| eBGP (exterior) | OGP — between different people's gateways |
| BGP WITHDRAW | Federation revocation |

**What we're NOT borrowing:** multi-hop routing, route tables, path computation, convergence. OGP is strictly point-to-point peering between two gateways. BGP started the same way.

---

## Architecture

```
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│        David's Gateway          │         │         Stan's Gateway          │
│   gw:david.proctor@trilogy.com  │         │  gw:stan.huseletov@trilogy.com  │
│      (OpenClaw implementation)  │         │      (OpenClaw implementation)  │
│                                 │         │                                 │
│  ┌──────────┐  ┌─────────────┐  │         │  ┌──────────┐  ┌─────────────┐  │
│  │  Junior  │  │  Sterling   │  │         │  │ Stan's   │  │  Stan's     │  │
│  │  (main)  │  │  (finance)  │  │         │  │  agent   │  │  agents     │  │
│  └────┬─────┘  └─────────────┘  │         │  └────┬─────┘  └─────────────┘  │
│       │   internal agent comms  │         │       │   internal agent comms  │
│       └──── (iBGP equivalent) ──┤         ├───────┴── (iBGP equivalent) ────┤
│                                 │         │                                 │
│  OGP Policy:                    │         │  OGP Policy:                    │
│  • Stan: scope=calendar-read    │◄──OGP──►│  • David: scope=calendar-read   │
│  • Rate: 10 req/hr              │         │  • Rate: 10 req/hr              │
│  • Auth: Ed25519 signed         │         │  • Auth: Ed25519 signed         │
│                                 │         │                                 │
└─────────────────────────────────┘         └─────────────────────────────────┘

         Both gateways implement OGP. Neither knows nor cares what
         framework the other is built on.
```

---

## Four Design Principles

**1. Decentralized**
No central registry or authority. You share your gateway URL out-of-band (Telegram, email, whatever). The protocol handles everything from there. Any gateway can peer with any other OGP-compliant gateway without asking anyone for permission.

**2. Policy-driven**
Every relationship has explicit, bilateral scope. Nothing flows without a configured policy on both ends. You decide what Stan's gateway can ask yours to do — and Stan decides what your gateway can ask his.

**3. Session-oriented**
Trust is established once (the handshake), then messages flow within that relationship until explicitly revoked. No re-authentication on every message.

**4. Graceful teardown**
Either party can revoke at any time. Revocation is immediate, cryptographically clean, and notifies both parties.

---

## Protocol Flow

### Discovery
```
David's gateway               Stan's gateway
     │                              │
     │  GET /.well-known/ogp ──────►│
     │                              │
     │◄─── OGP gateway card ────────│
     │  { gatewayId,                │
     │    publicKey,                │
     │    capabilities,             │
     │    rateHints,                │
     │    ogpVersion }              │
```

### Handshake
```
David's gateway               Stan's gateway          Stan (human)
     │                              │                      │
     │  POST /ogp/request ─────────►│                      │
     │  { fromGatewayId,            │                      │
     │    fromPublicKey,            │                      │
     │    proposedScope }           │                      │
     │                              │── notification ─────►│
     │                              │  "David wants to     │
     │                              │   federate. Accept?" │
     │                              │                      │
     │                              │◄─ approve ───────────│
     │◄── POST /ogp/approve ────────│                      │
     │  { publicKey, confirmedScope}│                      │
     │                              │                      │
     │  [relationship active]       │  [relationship active]│
```

### Message Exchange (Phase 2)
```
David's gateway               Stan's gateway
     │                              │
     │  POST /ogp/message ─────────►│
     │  { intent: "propose_meeting",│
     │    payload: { ... },         │
     │    signature: Ed25519,       │
     │    nonce: uuid,              │
     │    replyTo: url }            │
     │                              │
     │                   [verify:   │
     │                    signature,│
     │                    scope,    │
     │                    rate]     │
     │                              │
     │◄── POST replyTo ─────────────│
     │  { available: ["Mon 2pm"] }  │
```

---

## Scope Negotiation (v0.2.0)

OGP v0.2.0 introduces a three-layer scope model for per-peer access control:

```
Layer 1: Gateway Capabilities  → What I CAN support (advertised globally)
Layer 2: Peer Negotiation      → What I WILL grant YOU (per-peer, during approval)
Layer 3: Runtime Enforcement   → Is THIS request within YOUR granted scope (doorman)
```

### ScopeBundle Schema

```json
{
  "version": "0.2.0",
  "grantedAt": "2026-03-23T10:30:00Z",
  "scopes": [
    {
      "intent": "agent-comms",
      "enabled": true,
      "rateLimit": { "requests": 100, "windowSeconds": 3600 },
      "topics": ["memory-management", "task-delegation"],
      "expiresAt": "2026-06-23T10:30:00Z"
    }
  ]
}
```

### Extended Federation Card (v0.2.0)

```json
{
  "version": "0.2.0",
  "displayName": "David's Gateway",
  "email": "david@example.com",
  "gatewayUrl": "https://david.example.com",
  "publicKey": "302a300506...",
  "capabilities": {
    "intents": ["message", "task-request", "status-update", "agent-comms"],
    "features": ["scope-negotiation", "reply-callback"]
  },
  "endpoints": {
    "request": "https://david.example.com/federation/request",
    "approve": "https://david.example.com/federation/approve",
    "message": "https://david.example.com/federation/message",
    "reply": "https://david.example.com/federation/reply/:nonce"
  }
}
```

### Approval with Scope Grants

When approving a federation request, the approving gateway can include scope grants:

```json
POST /federation/approve
{
  "peerId": "stan:18790",
  "approved": true,
  "protocolVersion": "0.2.0",
  "scopeGrants": {
    "version": "0.2.0",
    "grantedAt": "2026-03-23T10:30:00Z",
    "scopes": [
      {
        "intent": "agent-comms",
        "enabled": true,
        "rateLimit": { "requests": 10, "windowSeconds": 60 },
        "topics": ["memory-management"]
      }
    ]
  }
}
```

### Backward Compatibility

| Scenario | Behavior |
|---|---|
| v0.2 gateway approves v0.1 peer | No `scopeGrants` sent, default rate limits (100/hour) apply |
| v0.1 peer sends to v0.2 gateway | Allowed with default rate limits, logged as v0.1 access |
| v0.2 peer missing scope for intent | 403 Forbidden: "Intent 'X' not in granted scope" |
| v0.2 peer exceeds rate limit | 429 Too Many Requests with `Retry-After` header |

---

## Security Model

| Threat | Mitigation |
|---|---|
| Forged messages | Ed25519 signature on every message — private key never leaves gateway |
| Replay attacks | Nonce deduplication (24h window) + timestamp skew check (±5 min) |
| Scope creep | Per-peer intent whitelist — unlisted intent rejected before any LLM call |
| Token cost abuse | Per-peer rate limiting (sliding window) + global policy cap |
| DDoS | Concurrent request cap per peer + spike detection → auto-pause |
| Unauthorized access | Peer management endpoints require gateway auth token |
| Topic abuse | Topic restrictions for agent-comms — only allowed topics accepted |

---

## Implementation Status

| Phase | Description | Status |
|---|---|---|
| 0 | Keypair generation + `/.well-known/ogp` endpoint | ✅ Complete |
| 1 | Handshake, peer store, federation CLI | ✅ Complete |
| 2 | Signed message passing + async reply | ✅ Complete |
| 3 | Scope negotiation + rate limiting (v0.2.0) | ✅ Complete |
| 4 | Agentic negotiation + Portal UI | 🔄 Next |

**Reference implementation:** [dp-pcs/ogp](https://github.com/dp-pcs/ogp) (v0.2.0)
**Design repo:** [dp-pcs/openclaw-federation](https://github.com/dp-pcs/openclaw-federation)
**Design repo:** [dp-pcs/openclaw-federation](https://github.com/dp-pcs/openclaw-federation)

---

## Naming

**OGP** — Open Gateway Protocol.

Also: Original Gangster Protocol. Both are correct.

The name is an intentional nod to BGP's lineage. Interior gateway protocols (OSPF, EIGRP) handle routing within an autonomous system. Exterior gateway protocols (BGP) handle routing between autonomous systems owned by different parties. OGP handles federation between AI gateways owned by different people. The taxonomy fits.

Implemented first in OpenClaw. Not owned by OpenClaw.
