# Federation Protocol Design

## Discoverability
URL-based, no central registry. Gateway address = subdomain URL.
Published at: GET /.well-known/ogp

## Federation Card Schema
{
  gatewayId: "gw:{email}",
  publicKey: "ed25519:{base64}",
  displayName: "Human Name",
  capabilities: ["calendar-read", "web-search", "repo-read"],
  rateHints: { maxRequestsPerHour: 10 }
}

## Trust Model
Unilateral request + human approval (both sides get notified)

## Message Format
{
  from: "gw:david.proctor@trilogy.com",
  to: "gw:stanislav.huseletov@trilogy.com",
  intent: "propose_meeting_slots",
  payload: { ... },
  replyTo: "https://{gateway}/federation/reply/{nonce}",
  timestamp: ISO8601,
  nonce: uuid-v4,
  signature: "ed25519:{base64}"
}

## Endpoints
- GET  /.well-known/ogp                  → federation card (unauthenticated)
- POST /federation/request               → send handshake request (unauthenticated knock)
- POST /federation/message               → deliver federated message (signed)
- GET  /federation/peers                 → list my federation peers (authenticated, gateway owner only)
- DELETE /federation/peers/:gatewayId   → revoke relationship

## Security
- Ed25519 signatures on all messages
- Nonce dedup (24h window)
- Timestamp skew check (±5 min)
- Per-peer token bucket rate limiting
- Global policy cap (overrides per-peer)
- Scope whitelist per peer (intent-based)

## Relationship Lifecycle
- Default: permanent until revoked
- Optional: expiry date set at approval time
- Either side can revoke instantly

## Project Topic Auto-Registration (v0.2.9+)

When a project is created, its ID is automatically registered as an agent-comms topic for all approved peers at `summary` level. This enables project-scoped agent communication without manual topic configuration.

When a new peer is approved, all existing local projects are auto-registered as agent-comms topics for that peer.

```
1. ogp project create my-app "My App"
   → Registers 'my-app' as topic for all approved peers

2. ogp federation approve alice --intents agent-comms
   → Registers all local project IDs as topics for alice
```

## Entry Types (v0.2.9+)

Project contributions use "entry types" rather than "topics" in the CLI. The wire format field remains `topic` for backwards compatibility.

```bash
# CLI uses --type flag (--topic is hidden alias)
ogp project contribute my-app decision "Using PostgreSQL for persistence"
ogp project query my-app --type progress

# Wire format still uses topic field
{ "projectId": "my-app", "topic": "decision", "summary": "..." }
```

## Default-Deny Agent-Comms (v0.2.9+)

The `off` response level enables default-deny security posture. When a message hits `off`, the daemon returns a cryptographically signed rejection:

```json
{
  "status": "rejected",
  "reason": "topic-not-permitted",
  "topic": "unknown-topic",
  "signature": "ed25519:..."
}
```

This prevents silent drops and provides verifiable proof of rejection.
