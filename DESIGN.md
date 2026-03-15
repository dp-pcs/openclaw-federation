# Federation Protocol Design

## Discoverability
URL-based, no central registry. Gateway address = subdomain URL.
Published at: GET /.well-known/openclaw-federation

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
- GET  /.well-known/openclaw-federation  → federation card (unauthenticated)
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
