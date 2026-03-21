# OGP Phase 1 Demo — Trust Establishment

**Date:** 2026-03-16
**Status:** ✅ Proven working
**Commit:** `9565b3cc7` on `feature/federation` (dp-pcs/openclaw)

---

## Setup

Two isolated OpenClaw gateways running on the same machine (LatentGenius), different ports, different state directories, different Ed25519 keypairs.

| | Gateway A | Gateway B |
|---|---|---|
| Port | 12000 | 12010 |
| State dir | `~/.openclaw-fed-a/` | `~/.openclaw-fed-b/` |
| Gateway ID | `latent-genius.local:12000` | `latent-genius.local:12010` |
| Token | `fed-test-a-token` | `fed-test-b-token` |

---

## Step 1 — Start both gateways

**Terminal 1 (Gateway A):**
```bash
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-a/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-a \
OPENCLAW_GATEWAY_PORT=12000 \
node ~/Documents/GitHub/openclaw/dist/index.js gateway
```

**Terminal 2 (Gateway B):**
```bash
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-b/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-b \
OPENCLAW_GATEWAY_PORT=12010 \
node ~/Documents/GitHub/openclaw/dist/index.js gateway
```

Both output: `[gateway] listening on ws://127.0.0.1:1200X`

---

## Step 2 — Verify federation cards (distinct identities)

```bash
echo "=== Gateway A ===" && curl -s http://localhost:12000/.well-known/openclaw-federation | python3 -m json.tool
echo "=== Gateway B ===" && curl -s http://localhost:12010/.well-known/openclaw-federation | python3 -m json.tool
```

**Output:**
```json
=== Gateway A ===
{
    "gatewayId": "latent-genius.local:12000",
    "publicKey": "MCowBQYDK2VwAyEAEueSRfmgS1HhVsZIS0Wi-ze5vhD18443Gv76vzUz29w",
    "displayName": "Latent-Genius.local (port 12000)",
    "version": "2026.3.14",
    "capabilities": ["calendar-read", "web-search", "general"],
    "rateHints": { "maxRequestsPerMinute": 60 }
}
=== Gateway B ===
{
    "gatewayId": "latent-genius.local:12010",
    "publicKey": "MCowBQYDK2VwAyEALXsJP6g1cZRzdao3j5_O5Q3gUyRtlbb0AVBZYrrjulw",
    "displayName": "Latent-Genius.local (port 12010)",
    "version": "2026.3.14",
    "capabilities": ["calendar-read", "web-search", "general"],
    "rateHints": { "maxRequestsPerMinute": 60 }
}
```

✅ Two distinct gateway IDs with different Ed25519 public keys.

---

## Step 3 — Gateway A requests federation with Gateway B

```bash
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-a/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-a \
OPENCLAW_GATEWAY_PORT=12000 \
node ~/Documents/GitHub/openclaw/dist/index.js federation request \
  --gateway http://localhost:12010 \
  --scope calendar-read,web-search
```

**Output:**
```
✅ Federation request sent
Target: http://localhost:12010
Scope: calendar-read, web-search
```

---

## Step 4 — Gateway B lists pending peers

```bash
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-b/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-b \
OPENCLAW_GATEWAY_PORT=12010 \
node ~/Documents/GitHub/openclaw/dist/index.js federation list
```

**Output:**
```
Federation peers (1):

⏳ Latent-Genius.local (port 12000) (latent-genius.local:12000) - pending [inbound]
   URL: http://localhost:12000
   Scope: calendar-read, web-search
   Created: 2026-03-16T17:28:29.656Z
```

---

## Step 5 — Gateway B approves Gateway A

```bash
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-b/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-b \
OPENCLAW_GATEWAY_PORT=12010 \
node ~/Documents/GitHub/openclaw/dist/index.js federation approve latent-genius.local:12000
```

**Output:**
```
✅ Federation approved: Latent-Genius.local (port 12000) (latent-genius.local:12000)
```

Approval callback fires to Gateway A's `/federation/approve` endpoint, which flips A's record to approved.

---

## Step 6 — Verify both sides show mutual approval

```bash
echo "=== Gateway A peers ===" && \
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-a/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-a \
OPENCLAW_GATEWAY_PORT=12000 \
node ~/Documents/GitHub/openclaw/dist/index.js federation list

echo "=== Gateway B peers ===" && \
OPENCLAW_CONFIG_PATH=~/.openclaw-fed-b/openclaw.json \
OPENCLAW_STATE_DIR=~/.openclaw-fed-b \
OPENCLAW_GATEWAY_PORT=12010 \
node ~/Documents/GitHub/openclaw/dist/index.js federation list
```

**Output:**
```
=== Gateway A peers ===
Federation peers (1):

✅ Latent-Genius.local (port 12010) (latent-genius.local:12010) - approved [mutual]
   URL: http://localhost:12010
   Scope: calendar-read, web-search
   Created: 2026-03-16T17:28:47.021Z
   Approved: 2026-03-16T17:29:12.000Z

=== Gateway B peers ===
Federation peers (1):

✅ Latent-Genius.local (port 12000) (latent-genius.local:12000) - approved [mutual]
   URL: http://localhost:12000
   Scope: calendar-read, web-search
   Created: 2026-03-16T17:28:29.656Z
   Approved: 2026-03-16T17:28:46.999Z
```

---

## Result

Both gateways show `approved [mutual]` — OGP Phase 1 trust establishment is working end-to-end.

- ✅ Discovery via `/.well-known/openclaw-federation`
- ✅ Ed25519 keypairs generated and persisted per gateway
- ✅ Federation request received and stored as pending
- ✅ Human-initiated approval via CLI
- ✅ Bilateral approval callback — both sides flip to approved
- ✅ `[mutual]` display once relationship is established

**Next:** Phase 2 — signed message passing between approved gateways.
