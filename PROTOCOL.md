# OGP — OpenClaw Gateway Protocol

> *"Original Gangster Protocol. Also: OpenClaw Gateway Protocol."*

## What It Is

OGP is a federation protocol that lets two OpenClaw gateways, owned by different people, exchange structured agent messages with explicit trust, scoped permissions, and rate controls — without either person acting as a relay.

In plain terms: your AI assistant can call your colleague's AI assistant directly. Neither of you has to copy-paste messages between them.

---

## The BGP Parallel

OGP borrows its trust and policy model from **BGP (Border Gateway Protocol)** — the protocol that handles routing between autonomous networks on the internet. The parallel isn't perfect (OGP doesn't compute paths or maintain route tables), but the *peering model* maps cleanly.

| BGP Concept | OGP Equivalent |
|---|---|
| Autonomous System (AS) | Individual gateway (`gw:david@trilogy.com`) |
| OPEN message | `GET /.well-known/openclaw-federation` |
| BGP session establishment | Handshake → human approval → key exchange |
| Route policy / filters | Per-peer scope (which intents are allowed) |
| MD5 session auth | Ed25519 signed messages |
| Route dampening | Per-peer rate limiting + abuse detection |
| iBGP (interior) | Agent-to-agent within one gateway (exists today) |
| eBGP (exterior) | OGP — between different people's gateways |
| BGP WITHDRAW | Federation revocation |

**What we're NOT borrowing:** multi-hop routing, route tables, path computation, convergence. OGP Phase 1 is strictly point-to-point peering. BGP started the same way.

---

## Architecture

```
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│        David's Gateway          │         │         Stan's Gateway          │
│   gw:david.proctor@trilogy.com  │         │  gw:stan.huseletov@trilogy.com  │
│                                 │         │                                 │
│  ┌──────────┐  ┌─────────────┐  │         │  ┌──────────┐  ┌─────────────┐  │
│  │  Junior  │  │  Sterling   │  │         │  │ Stan's   │  │  Stan's     │  │
│  │  (main)  │  │  (finance)  │  │         │  │  agent   │  │  agents     │  │
│  └────┬─────┘  └─────────────┘  │         │  └────┬─────┘  └─────────────┘  │
│       │   iBGP (internal)       │         │       │   iBGP (internal)       │
│       └──── agent-to-agent ─────┤         ├───────┴─── agent-to-agent ──────┤
│                                 │         │                                 │
│  OGP Policy:                    │         │  OGP Policy:                    │
│  • Stan: scope=calendar-read    │◄──OGP──►│  • David: scope=calendar-read   │
│  • Rate: 10 req/hr              │         │  • Rate: 10 req/hr              │
│  • Auth: Ed25519 signed         │         │  • Auth: Ed25519 signed         │
│                                 │         │                                 │
└─────────────────────────────────┘         └─────────────────────────────────┘
```

---

## Four Design Principles (borrowed from BGP)

**1. Decentralized**
No central registry or authority. You share your gateway URL out-of-band (Telegram, email, whatever). The protocol handles everything from there.

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
     │  GET /.well-known/           │
     │  openclaw-federation ───────►│
     │                              │
     │◄─── federation card ─────────│
     │  { gatewayId,                │
     │    publicKey,                │
     │    capabilities,             │
     │    rateHints }               │
```

### Handshake
```
David's gateway               Stan's gateway          Stan (human)
     │                              │                      │
     │  POST /federation/request ──►│                      │
     │  { fromGatewayId,            │                      │
     │    fromPublicKey,            │                      │
     │    proposedScope }           │                      │
     │                              │── Telegram notif ───►│
     │                              │  "David wants to     │
     │                              │   federate. Accept?" │
     │                              │                      │
     │                              │◄─ approve ───────────│
     │◄── POST /federation/approve ─│                      │
     │  { publicKey, confirmedScope}│                      │
     │                              │                      │
     │  [relationship active]       │  [relationship active]│
```

### Message Exchange (Phase 2)
```
David's gateway               Stan's gateway
     │                              │
     │  POST /federation/message ──►│
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

## Security Model

| Threat | Mitigation |
|---|---|
| Forged messages | Ed25519 signature on every message — private key never leaves gateway |
| Replay attacks | Nonce deduplication (24h window) + timestamp skew check (±5 min) |
| Scope creep | Per-peer intent whitelist — request for unlisted intent hard-rejected before any LLM call |
| Token cost abuse | Per-peer rate limiting (token bucket) + global policy cap |
| DDoS | Concurrent request cap per peer + spike detection → auto-pause |
| Unauthorized access | `/federation/peers` management endpoints require gateway auth token |

---

## Implementation Status

| Phase | Description | Status |
|---|---|---|
| 0 | Keypair generation + `/.well-known` endpoint | ✅ Complete |
| 1 | Handshake, peer store, federation CLI | 🔄 In progress |
| 2 | Signed message passing + async reply | ⬜ Planned |
| 3 | Rate limiting + abuse prevention | ⬜ Planned |
| 4 | Portal UI + natural language commands | ⬜ Planned |

**Branch:** `feature/federation` on [dp-pcs/openclaw](https://github.com/dp-pcs/openclaw) (private fork)
**Design repo:** [dp-pcs/openclaw-federation](https://github.com/dp-pcs/openclaw-federation)

---

## Naming

**OGP** — OpenClaw Gateway Protocol.

Also: Original Gangster Protocol. Both are correct.

The name is an intentional nod to BGP's lineage. IGPs (OSPF, EIGRP) handle interior routing. EGPs (BGP) handle exterior routing between autonomous systems. OGP handles exterior federation between autonomous OpenClaw gateways. The taxonomy fits.
