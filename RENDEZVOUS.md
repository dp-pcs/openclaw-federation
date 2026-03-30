# OGP Rendezvous & Invite Flow Specification

> Protocol version: v0.2.14 (rendezvous), v0.2.15 (invite flow)

## Overview

The rendezvous subsystem solves the public accessibility problem for OGP federation without requiring port forwarding, third-party tunnel accounts, or manual URL exchange.

Two primitives:

1. **Rendezvous registration** — gateways publish their current IP:port to a lightweight coordination server on startup, keyed by public key. Peers look each other up by pubkey.
2. **Invite flow** — a short-lived token that encapsulates a pubkey + connection hints, enabling one-command federation with zero manual coordination.

---

## Design Principles

- **Rendezvous server sees only connection metadata** — IP, port, pubkey, timestamp. Never message content.
- **Identity stays key-based** — peers are always identified by Ed25519 public key, not by IP or hostname. IPs are ephemeral; keys are permanent.
- **Stateless by design** — the rendezvous server holds no durable state. Registrations expire (90s TTL). A restart means peers re-register on next heartbeat. No data loss risk.
- **Optional, not required** — gateways with a static IP or existing tunnel continue working unchanged. Rendezvous is an additional discovery path.
- **Trust is still bilateral** — rendezvous enables discovery, not automatic trust. After a peer is discovered, the standard OGP federation approval flow applies.

---

## Rendezvous Server Protocol

### Registration

```
POST /register
Content-Type: application/json

{
  "pubkey": "<ed25519 public key hex>",
  "port": 18790,
  "timestamp": 1743200000000
}
```

Response:
```json
{ "ok": true, "yourIp": "203.0.113.42" }
```

- Server extracts caller IP from `x-forwarded-for` header (ALB sets this) or `socket.remoteAddress`
- Registration TTL: 90 seconds
- Peers should heartbeat every 30 seconds (re-POST /register)

### Peer Lookup

```
GET /peer/:pubkey
```

Response (found):
```json
{
  "pubkey": "<pubkey>",
  "ip": "203.0.113.42",
  "port": 18790,
  "lastSeen": 1743200000000
}
```

Response (not found or expired):
```
404 { "error": "Peer not found or expired" }
```

### Deregistration

```
DELETE /peer/:pubkey
```

Called by daemon on graceful shutdown. Best-effort — TTL handles cleanup if shutdown is unclean.

### Health Check

```
GET /
```

Response:
```json
{ "ok": true, "peers": 3 }
```

---

## Invite Flow Protocol (v0.2.15)

The invite flow allows zero-coordination federation: one peer generates a short code, shares it out-of-band (Telegram, Slack, email), and the other peer uses it to connect.

### Generate Invite

```
POST /invite
Content-Type: application/json

{
  "pubkey": "<pubkey>",
  "port": 18790
}
```

Response:
```json
{
  "ok": true,
  "token": "a3f7k2",
  "expiresIn": 600
}
```

- Token: 6-char alphanumeric (case-insensitive, lowercase canonical)
- TTL: 600 seconds (10 minutes)
- Non-consuming: multiple peers can accept the same token within TTL

### Resolve Invite

```
GET /invite/:token
```

Response (valid):
```json
{
  "pubkey": "<pubkey>",
  "ip": "203.0.113.42",
  "port": 18790
}
```

Response (expired or invalid):
```
404 { "error": "Invite not found or expired" }
```

---

## Daemon Integration

### Config

```json
{
  "rendezvous": {
    "enabled": true,
    "url": "https://rendezvous.elelem.expert"
  }
}
```

### Startup Sequence (if rendezvous.enabled)

1. Detect own public IP: `GET https://api.ipify.org?format=json`
2. `POST {rendezvous.url}/register` with pubkey + port + timestamp
3. Start 30-second heartbeat interval
4. Log: `[OGP] Registered with rendezvous at {url} as {pubkey.slice(0,8)}...`

### Shutdown Sequence

1. `DELETE {rendezvous.url}/peer/{pubkey}` (best effort, non-blocking)
2. Clear heartbeat interval

### Peer Connect Flow

When `ogp federation connect <pubkey>` is called (no explicit URL):

1. `GET {rendezvous.url}/peer/{pubkey}`
2. If found: use `http://{ip}:{port}` as peer URL, proceed with standard federation request
3. If not found: return error — "Peer not found in rendezvous. Ask them to enable rendezvous or share their URL directly."

### Invite Command Flow

`ogp federation invite`:
1. `POST {rendezvous.url}/invite` with own pubkey + port
2. Print: `Your invite code: {token}  (expires in 10 minutes)`
3. Print: `Share this with your peer — they run: ogp federation accept {token}`

`ogp federation accept <token>`:
1. `GET {rendezvous.url}/invite/{token}`
2. If found: call federation connect logic with returned `{ip, port, pubkey}`
3. Print: `Connected to {pubkey.slice(0,8)}... via rendezvous ✅`
4. If not found: `Invite code not found or expired. Ask your peer to generate a new one.`

---

## Security Considerations

- The rendezvous server is a **coordination plane only** — it cannot intercept, read, or modify OGP messages
- Registrations are unauthenticated by design (IP:port hints are not sensitive)
- Invite tokens are short-lived (10 min) and guessable only via brute force of a 36^6 (~2.2B) space
- After discovery, all trust establishment follows standard OGP bilateral approval — rendezvous discovery does not grant any permissions
- Self-hosting is supported for operators who require full control over the coordination layer

---

## Public Instance

- URL: `https://rendezvous.elelem.expert`
- Hosted on AWS ECS Fargate (us-east-1), behind Application Load Balancer
- Source: `packages/rendezvous/` in [dp-pcs/ogp](https://github.com/dp-pcs/ogp)
