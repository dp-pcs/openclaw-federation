# OGP Phase 3 — Rate Limiting, Real Intents & Abuse Prevention

## Goal
Make OGP production-ready: protect against abuse, wire in real data sources,
and prove the meeting-scheduling use case end-to-end.

---

## What Phase 3 Builds

### 1. Per-peer token bucket rate limiting
- Each approved peer gets a rate limit bucket (e.g. 10 requests/hour by default)
- Bucket refills gradually — burst drains it fast, then hits a wall
- Stored in peer record: `{ bucket: { tokens: N, lastRefill: ISO8601 } }`
- On each inbound message: check bucket before processing, deduct 1 token, reject with 429 if empty
- Global policy cap in `openclaw.json` overrides per-peer settings

### 2. Real web-search intent
- Replace echo stub with actual Brave Search API call (already have the API key)
- Return top 3-5 results: title, URL, snippet
- This makes `federation send --intent web-search` genuinely useful

### 3. Calendar intent (the meeting scheduling demo)
- `calendar-read` intent: given a date range, return available slots
- Calls Google Calendar API via existing `gws` CLI / gog skill
- Returns: `{ available: ["Mon 2pm", "Wed 10am"], timezone: "America/Denver" }`
- This enables the flagship demo: David tells Junior to find a meeting time with Stan

### 4. Spike detection + auto-pause
- If a peer sends 3x their normal rate in 10 minutes → auto-pause relationship + notify owner
- Owner can re-enable via `openclaw federation unpause <gatewayId>`
- Logged to `federation-audit.log` in state dir

### 5. Concurrent request cap
- Max 2 federated requests executing simultaneously per peer
- 3rd request queued, not rejected (unless queue depth > 5, then reject)

---

## The Meeting Scheduling Demo (end goal)

**Setup:**
- David's local gateway (port 12000) has Google Calendar access
- "Stan's" gateway (port 12010) has Google Calendar access

**Flow:**
```
David: "Find a 30-minute meeting with Stan next week"

Junior (Gateway A):
→ federation send latent-genius.local:12010
  --intent calendar-read
  --payload {"range": "next week", "duration": 30}

Stan's Gateway (B) receives:
→ verifies signature ✅
→ checks scope includes calendar-read ✅
→ checks rate limit ✅
→ reads Stan's Google Calendar
→ returns { available: ["Mon 3pm", "Tue 10am", "Wed 2pm"] }

Gateway A receives reply:
→ Junior: "Stan is free Monday 3pm, Tuesday 10am, or Wednesday 2pm.
   Which works for you?"

David: "Monday 3pm"

Junior: creates Google Calendar event for David + sends confirmation to Stan's gateway
```

Zero human relay. This is the proof case.

---

## Phase 3 Sequence

1. Rate limiting (token bucket) — 2-3 days
2. Real web-search via Brave API — 1 day
3. Calendar intent (calendar-read) — 2-3 days  
4. Spike detection + auto-pause — 1 day
5. End-to-end meeting scheduling demo — 1 day
6. `DEMO-phase3.md` + re-record all demos clean — 1 day

**Total estimate:** ~1 week of focused development

---

## What Phase 3 Does NOT Include
- Calendar write (creating events) — Phase 4
- Natural language intent parsing — Phase 4
- Portal UI for federation — Phase 4
- Multi-hop routing — not in scope for v1

---

## Backlog items captured for Phase 4+
See `BACKLOG.md` for the full post-MVP list including:
- Scope editor on approve
- Project-tagged scopes with auto-expiry
- Clawporate portal federation tab
- QR code pairing
- `openclaw-enterprise` integration (per-user federation addresses)
