# OGP Development Findings & Lessons Learned

**Last updated:** 2026-03-16

---

## Phase 0 — Keypair Generation + Well-Known Endpoint

### What worked
- Ed25519 keypair generation via `node:crypto` `generateKeyPairSync` — clean, no deps
- Persisting keypair as base64url DER to `{stateDir}/federation-keypair.json` (mode 0600)
- `/.well-known/openclaw-federation` returning JSON card — publicly accessible before auth middleware

### Adjustments made
- Gateway card initially used hostname only → both test gateways showed same ID since same machine
- **Fix:** Appended port to gatewayId when non-default: `latent-genius.local:12000` vs `latent-genius.local:12010`
- **Good to know:** In real deployment (different machines), hostname alone works fine. Port disambiguation is test-only.

### Good to know
- OpenClaw gateway config requires `gateway.mode = "local"` — without it, gateway refuses to start
- `gateway.port` in config is overridden by `OPENCLAW_GATEWAY_PORT` env var (which takes priority)
- `--profile` flag for isolated gateways inherits the main config — use `OPENCLAW_CONFIG_PATH` + `OPENCLAW_STATE_DIR` instead
- pnpm required (not npm) — OpenClaw repo uses pnpm workspaces
- Build command: `cd ~/Documents/GitHub/openclaw && pnpm build`

---

## Phase 1 — Handshake & Trust Establishment

### What worked
- `POST /federation/request` receiving inbound requests and saving as pending peer ✅
- `federation list` CLI showing pending/approved peers ✅
- `federation approve` CLI with bilateral callback ✅
- Per-peer public key storage — each gateway stores the other's Ed25519 public key ✅

### Bugs found and fixed

**Bug 1: Hardcoded port 18789 in CLI**
- `federation request` and `federation approve` used hardcoded `http://localhost:18789` to fetch own card
- **Fix:** Read `OPENCLAW_GATEWAY_PORT` env var, fall back to 18789
- **Lesson:** Any CLI command that calls "local gateway" must respect env var port override

**Bug 2: Peer saved with URL as gatewayId**
- When A sent a request to B, A saved the peer using `http://localhost:12010` as the gatewayId
- **Fix:** Fetch target's `/.well-known/openclaw-federation` first, use their real `gatewayId`
- **Lesson:** Always fetch the target's federation card before saving — don't invent IDs

**Bug 3: Approve callback using wrong endpoint**
- `federation approve` was POSTing to `/federation/approve` but sending a new request body (not an approval)
- Caused A's record to be created as a new inbound request instead of flipping existing pending→approved
- **Fix:** `/federation/approve` endpoint specifically looks up outbound pending peer by URL and flips status
- **Lesson:** Approval callback needs its own endpoint with different semantics from request

**Bug 4: `[mutual]` display**
- After approval, both sides showed `approved [inbound]` or `approved [outbound]`
- Direction of initiation is handshake metadata only — once approved, relationship is bilateral
- **Fix:** Show `approved [mutual]` when status === approved, regardless of initiator
- **Lesson:** UX framing matters — "mutual" is the correct mental model for users

### Protocol clarification
- OGP peering is **bilateral by design** — both sides can send messages once approved
- Asymmetric scope (A can query B but B can't query A) is a future backlog item
- BGP parallel holds: peering is mutual, policy controls what flows

---

## Phase 2 — Signed Message Passing

### What worked
- `POST /federation/message` with full validation stack ✅
- Ed25519 signature verification on receipt ✅
- Scope enforcement — unlisted intent rejected before any processing ✅
- Nonce anti-replay check ✅
- Timestamp skew check (±5 minutes) ✅
- Async reply via `replyTo` URL callback ✅
- `federation send` CLI with 30s reply polling ✅
- **Ping intent working end-to-end** ✅

### Bugs found and fixed

**Bug 1: Ed25519 algorithm name**
- Phase 2 agent used `createSign("SHA512")` — wrong for Ed25519
- **Fix 1:** Changed to `createSign("Ed25519")` — still failed
- **Fix 2:** Node v25 requires one-shot `sign(null, buffer, keyObject)` / `verify(null, buffer, keyObject, sig)` — not `createSign`/`createVerify`
- **Lesson:** Ed25519 in Node is version-sensitive. `createSign("Ed25519")` works on some versions, one-shot `sign()` is the reliable cross-version approach

**Bug 2: Key import format**
- Passing raw base64url buffer directly to `createSign` → "Invalid digest" error
- **Fix:** Import key as `KeyObject` first using `createPrivateKey({ key: buffer, format: "der", type: "pkcs8" })`
- **Lesson:** Node crypto APIs want KeyObjects, not raw buffers, for signing operations

**Bug 3: In-process memory sharing**
- CLI polled `getReply(nonce)` via direct import of federation-message-handler module
- CLI is a separate process from gateway — they don't share module memory
- Reply was stored in gateway process, CLI looked in its own (empty) process
- **Fix:** CLI polls `GET /federation/reply/{nonce}` via HTTP — gateway stores reply in its own memory, CLI reads via HTTP
- **Lesson:** CLI and gateway are always separate processes. Any shared state must go through HTTP.

**Bug 4: DuckDuckGo fetch hanging**
- `web-search` intent used DuckDuckGo instant answer API — hangs unpredictably
- Caused 30s timeout on web-search even though protocol was working
- **Fix:** Replaced with instant echo response for Phase 2 demo; real search in Phase 3
- **Lesson:** External APIs in intent handlers must have aggressive timeouts. Async intent processing + silent error swallowing hides these failures completely.

**Bug 5: `sendReply` timeout missing**
- `sendReply()` had no timeout — if remote gateway was slow/unreachable, it hung indefinitely
- **Fix:** Added 5s `AbortController` timeout to `sendReply`
- **Lesson:** Every outbound fetch in federation handlers needs a timeout

---

## General Lessons Learned

### Architecture
1. **CLI ≠ gateway process** — never share in-process state between them; always HTTP
2. **Env vars for port isolation** — `OPENCLAW_GATEWAY_PORT` is the right knob for test gateways
3. **Always fetch the other gateway's card first** — don't construct their identity from local data
4. **Silent error swallowing is dangerous** — `sendReply` was swallowing all errors; fine for production but terrible for debugging

### Testing
1. **Test with curl first** — before debugging CLI, manually curl the endpoints to isolate where failure is
2. **In-process test is misleading** — the CLI import trick looked right but was wrong; always test the actual HTTP path
3. **Two gateways on same machine works** — different ports + state dirs is sufficient for development; no need for separate machines until real multi-user testing
4. **Restart gateways after every build** — they load the old dist; always kill and restart after `pnpm build`

### Node.js / Crypto
1. **Ed25519 in Node v25:** use `sign(null, buffer, key)` and `verify(null, buffer, key, sig)` — not `createSign("Ed25519")`
2. **Always import keys as KeyObjects** before passing to crypto operations
3. **Keys stored as base64url DER** — PKCS8 for private, SPKI for public

---

## What's Real vs Mocked in Phase 2

| Component | Status |
|---|---|
| Ed25519 keypair generation | ✅ Real |
| `/.well-known/ogp` card | ✅ Real |
| Federation request/approve handshake | ✅ Real |
| Peer store with public keys | ✅ Real |
| Message signing (Ed25519) | ✅ Real |
| Signature verification | ✅ Real |
| Scope enforcement | ✅ Real |
| Nonce anti-replay | ✅ Real |
| Timestamp skew check | ✅ Real |
| Async reply callback | ✅ Real |
| Ping intent | ✅ Real |
| Web-search result | 🟡 Echo stub — real search in Phase 3 |
| Calendar intent | ⬜ Not yet built |

---

## Naming History
- Started as **OGP (OpenClaw Gateway Protocol)**
- Renamed to **OGP (Open Gateway Protocol)** — vendor-neutral, any framework can implement
- AGP considered but conflicts with existing "Agent Gateway Protocol" (ACP-based, gRPC)
- AGP also conflicts with "Accelerated Graphics Port" (Intel, 1996)
- OGP is clean in the AI/gateway space
- "Also: Original Gangster Protocol" — stays in the docs forever

---

## Phase 3A — Intent Handler Registry (continued)

### What worked
- `federation register-intent <intent> --command <cmd>` writes to `ogp-intent-registry.json` ✅
- `/.well-known/ogp` now reads registry dynamically on every request — capabilities update without restart ✅
- Command dispatch with `{param}` substitution working ✅
- `federation intents` CLI lists registered handlers ✅

### Bug fixed
- Well-known endpoint served static startup-cached card → capabilities never updated after registering intents
- **Fix:** Handler reloads registry on each request; removed `max-age=3600` cache header
- **Lesson:** Any capability that changes at runtime must be read dynamically, not cached at startup

---

## Calendar Demo Design Decisions

### Decision: Stan's gateway initiates the meeting invite, not David's
**Why:** In real life, the person requesting the meeting sends the invite. David is the attendee, not the organizer. If David's gateway created the event and invited Stan, that's backwards — David would be hosting a meeting Stan asked for.
**Result:** `calendar-write` executes on the requesting gateway (Stan/Alex), with David's email as attendee.

### Decision: David's gateway is the calendar authority for availability only
**Why:** David's gateway checks *his* calendar and returns available slots. That's all it does for calendar-read. It doesn't create anything.
**Result:** Clean separation — read happens at David's gateway, write happens at Stan's gateway.

### Decision: Email address goes in the federation card
**Why:** When Stan's gateway creates a calendar event and needs to invite David, it needs David's email. Without it, the agent would have to ask the user or guess. Since the federation card is the authoritative identity document for a gateway, email belongs there.
**Result:** `FederationCard` gets an `email` field. When Stan approves David as a peer, he stores David's email from David's card. `calendar-write` pulls `peer.email` for the attendee list automatically — no extra payload coordination needed.
**Alternative considered:** Pass email in the `calendar-write` payload each time. Rejected because it requires the sender to already know the email, defeating the purpose of the card.

### Decision: Gateway A = Google Calendar (david.proctor@trilogy.com), Gateway B = Apple Calendar (david@theproctors.cloud)
**Why:** These are David's two real calendar setups. Using real data makes the demo authentic. The fact that they use different calendar systems (Google vs Apple) is the whole point — OGP abstracts the implementation, both gateways speak `calendar-read`.
**Result:** Gateway A uses `gws calendar freebusy` (gog CLI). Gateway B uses `icalbuddy` (macOS CLI) for read and AppleScript for write.

### Decision: Meeting preference windows enforced server-side (receiving gateway)
**Why:** David doesn't want to expose his full calendar to Stan's gateway — just the slots within his configured window. Enforcing on the receiving side means David's privacy preferences are always respected regardless of what the requester asks for.
**Result:** David's gateway config: `acceptMeetingsWindow: { start: "09:00", end: "11:30", tz: "America/Denver" }`. Even if Stan asks for 8am-5pm, David's gateway only returns slots in 9am-11:30am.
**BGP analogy:** Route filtering — you only advertise the routes you choose to share.

### Decision: Stan (demo persona renamed to "Alex" for clean recording)
**Why:** Stan is David's real coworker. Using him in a recorded demo creates ambiguity about whether real calendar data is involved. "Alex" is clearly fictional.
