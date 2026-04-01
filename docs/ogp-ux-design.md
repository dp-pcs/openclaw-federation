# OGP UX Design — Agentic Federation Flow

*Captured 2026-03-18 from David Proctor*

## Vision

Federation should be invisible to end users. When you say "find time with Stan next week," your agent handles everything — peer lookup, trust establishment, scheduling — with minimal interruption. The protocol is infrastructure; the agent is the UX.

---

## Full Flow (Happy Path — existing federation)

1. User: "Find some time for a 30-minute call with Stan next week"
2. Agent checks peer address book → Stan found, status=approved
3. Agent sends `calendar-read` intent to Stan's gateway for next week
4. Agent compares returned slots with user's own calendar
5. Agent proposes best overlap: "Stan is free Monday 10am and Wednesday 2pm — which works for you?"
6. User picks one → agent creates event on own calendar, invites Stan
7. Agent confirms: "Done — calendar invite sent to Stan for Monday at 10am"

Variant — "book Thursday specifically":
- Skip comparison, just query Stan for Thursday availability
- If he's free → book it
- If not → "Stan is busy Thursday — want me to find another time?"

---

## Full Flow — No Existing Federation

1. User: "Find time with Stan next week"
2. Agent checks peer address book → Stan not found
3. Agent: "I don't have a federation with Stan. What's his gateway URL?"
4. User provides URL (or email if discovery is implemented later)
5. Agent sends federation request → scoped: `calendar-read, ping`
6. Agent: "Federation request sent to Stan's gateway. I'll let you know when he approves."

*(request is stored; original scheduling intent is remembered)*

---

## Inbound Request Flow (Stan's side)

When a federation request hits Stan's `/federation/request` endpoint:

1. Stan's gateway detects new pending request (event-driven or polled via cron)
2. Stan's agent is notified proactively:

> "David Proctor's gateway (david-gw.example.com) wants to connect with you.
> They're requesting access to: **calendar-read**, **ping**
>
> **One-way trust:** You can read David's calendar (if he grants it), but David cannot read yours unless you separately request access.
> **Two-way trust:** Both gateways grant each other calendar-read access. Scheduling works in both directions.
>
> Which would you like? [One-way] [Two-way] [Decline]"

3a. Stan chooses **One-way**:
   - Stan's gateway approves the request
   - Sends acceptance back to David's gateway
   - David's gateway notified: "Stan approved your federation request. Continuing with scheduling..."
   - Original scheduling flow resumes automatically

3b. Stan chooses **Two-way**:
   - Stan's gateway approves the request
   - Stan's gateway automatically sends a counter-request to David's gateway
   - David's gateway detects inbound request, either:
     - Auto-approves (if policy allows) and notifies David: "Two-way federation established with Stan"
     - Or prompts David: "Stan approved and wants two-way access — approve? [Yes] [No]"
   - Both sides confirmed → scheduling resumes

3c. Stan chooses **Decline**:
   - Rejection sent back to David's gateway
   - David's agent notified: "Stan declined the federation request. Scheduling cancelled."

---

## Post-Approval Continuation

When David's gateway receives federation approval:
- Resume the original pending scheduling request automatically
- Do NOT make David re-ask
- Notify David: "Federation established with Stan. Continuing..."

This requires storing "pending intent" state when a federation request is triggered mid-task.

---

## Implementation Notes

### What needs to be built

| Feature | Priority | Notes |
|---|---|---|
| Agent peer lookup before scheduling | High | Skill-level: check `federation list` first |
| Proactive inbound request detection | High | Event on `/federation/request` hit → notify agent |
| One-way vs two-way prompt at approval | High | New `federation approve` UX; `--mutual` flag for auto counter-request |
| Pending intent storage + resume | Medium | Store original intent in state; resume on approval callback |
| Auto-continue after approval | Medium | Approval callback triggers scheduling flow |
| Gateway URL discovery from email | Low | DNS TXT record or HTTPS well-known lookup by email domain |

### Pending Intent State

When a federation request is triggered during a scheduling task, store:
```json
{
  "pendingIntent": {
    "type": "schedule",
    "targetPeer": "stan-gateway-url",
    "originalRequest": "find time with Stan next week",
    "userId": "8311956999",
    "createdAt": "2026-03-18T..."
  }
}
```
On approval, load this and resume.

### Trust Direction Semantics

- **One-way A→B:** A can request intents from B; B cannot request from A (unless B separately initiates)
- **Two-way:** Both sides have approved each other; either can initiate
- Current implementation is effectively one-way by default (requester can send, responder cannot initiate back without a separate request)
- `--mutual` flag on `federation request` sends requests to both endpoints simultaneously

### ogp-config.json — Demo Shortcut, Not Production Pattern

The current implementation uses `ogp-config.json` in the gateway state directory to store:
- `displayName` and `email` (identity)
- `acceptMeetingsWindow` (meeting preferences)

**This is a demo shortcut only.** In the real product, the federation card should be dynamically assembled from existing OpenClaw config — no separate config file needed:

| Data | Real Source |
|---|---|
| Identity / email | Gateway's agent identity + USER.md |
| Calendar integration | Existing OpenClaw calendar settings (user already configured this) |
| Meeting window | User preference in OpenClaw settings (needs a settings surface) |
| Timezone | Already in OpenClaw agent config |

The `ogp-config.json` file exists because we needed to bootstrap the federation card without wiring into real OpenClaw internals during the prototype phase. Before OGP ships in any real form, the `/federation/card` endpoint must read from OpenClaw's native config, not a sidecar file.

**Architectural principle:** OGP is a protocol layer, not a data store. Skills are add-ons. Neither should rewrite where OpenClaw stores user data. OGP reads from OpenClaw's existing config — it does not own identity, calendar settings, or user preferences. The only files OGP should write are its own protocol artifacts: keypairs, peer relationships, and the intent registry.

**Risk:** If agents read ogp-config.json and describe it as "your calendar preferences," users may think OGP has more access than it does. The agent should be clear: ogp-config.json is identity metadata for the federation handshake — it does not grant calendar access. Actual calendar queries go through the registered intent handlers (shell scripts / calendar APIs).

### Gateway Self-Awareness (Future)

The gateway should inject its own URL into the agent's context at startup — as a system prompt variable or workspace file — so the agent can answer "what is your gateway address?" without having to query `/.well-known/ogp` or guess from config.

Currently the agent has to infer its own address. That's a gap.

### Discovery (Future)

Long-term: resolve a user's gateway from their email address via DNS TXT record:
```
_ogp.example.com TXT "v=ogp1; gw=https://david-gw.example.com"
```
Fallback: user provides URL manually (current approach).

---

## Article Angle

The scheduling demo works. But the *real* story is this flow: two AI assistants negotiating trust and coordinating on behalf of their users, with minimal human involvement. The humans set policy (approve/decline, one-way/two-way), the agents do the work.

That's what makes OGP different from a skill: it's not one agent using a tool. It's two agents, representing two people, coordinating across a boundary — the way human assistants would, but faster and without the email chain.

---

## Public Gateway Exposure (ogp-expose skill)

### The Problem

For two users to federate via OGP, their gateways must be able to reach each other over HTTP/HTTPS. This is straightforward when both gateways are deployed to cloud infrastructure with public IPs (like ECS, Railway, or VPS hosting). But many OpenClaw users run their gateway locally on `http://localhost:18789` during development or for personal use.

**Local gateways are not reachable from the internet.** A user on `localhost` cannot receive federation requests from a peer unless they expose their gateway publicly.

Traditionally, this would require:
- Configuring router port forwarding
- Setting up dynamic DNS for a home IP address
- Managing firewall rules
- Understanding network topology

This is a non-starter for most users. We need a **zero-configuration** way to expose a local gateway publicly.

### The Solution: Tunneling with cloudflared or ngrok

Modern tunneling tools like **cloudflared** (Cloudflare Tunnel) and **ngrok** solve this by creating a secure reverse proxy from a public URL to your local port:

```
Internet → https://abc-xyz.trycloudflare.com → cloudflared → http://localhost:18789
```

**How it works:**
1. You run `cloudflared tunnel --url http://localhost:18789` on your machine
2. Cloudflare assigns you a temporary public URL like `https://abc-xyz.trycloudflare.com`
3. All traffic to that URL is securely forwarded to your local gateway
4. No router configuration, no firewall changes, no static IP needed

**Why cloudflared over ngrok:**
- **Free and unlimited** — no account required, no session limits
- **HTTPS by default** — automatic TLS termination
- **No bandwidth caps** — unlike ngrok's free tier
- **Cloudflare's global network** — low latency worldwide

Ngrok is still supported as a fallback (some users already have it installed), but we prefer cloudflared for simplicity.

### The `gateway.remote.url` Config Field

When you run a tunnel, your gateway needs to know its public URL so it can:
- Generate correct callback URLs in federation requests (like `replyTo: https://abc-xyz.trycloudflare.com/federation/reply/...`)
- Advertise the correct gateway URL in its federation card

We introduce a new config field in `openclaw.json`:

```json
{
  "gateway": {
    "port": 18789,
    "remote": {
      "url": "https://abc-xyz.trycloudflare.com"
    }
  }
}
```

**Behavior:**
- If `gateway.remote.url` is set, the gateway uses this as its public-facing URL for all federation operations
- If not set, the gateway falls back to `http://localhost:{port}` (local-only mode)
- The `ogp-expose setup` command automatically sets this field after starting the tunnel

This allows the same gateway to switch between local-only and public modes without code changes — just a config update and restart.

### The `ogp-expose` Skill

The `ogp-expose` skill wraps the entire tunnel setup flow into three simple commands:

| Command | What it does |
|---|---|
| `ogp-expose setup` | Install/check for cloudflared, start tunnel, capture public URL, update `openclaw.json`, restart gateway |
| `ogp-expose status` | Check if tunnel is running, show current public URL |
| `ogp-expose stop` | Kill tunnel process, optionally remove `gateway.remote.url` from config |

**Example user flow:**

```
User: "I want to federate with my friend"
Agent: "Is your gateway running locally or deployed publicly?"
User: "Locally"
Agent: "I'll expose your gateway publicly. One moment..."

[Agent runs ogp-expose setup]

Agent: "Done! Your gateway is now accessible at:
https://abc-xyz.trycloudflare.com

Share this command with your friend:
openclaw federation request --gateway https://abc-xyz.trycloudflare.com

Your federation card is live at:
https://abc-xyz.trycloudflare.com/.well-known/ogp
"
```

The user doesn't need to:
- Know what a tunnel is
- Install cloudflared manually
- Edit config files by hand
- Understand public vs. private IPs

The agent handles all of it.

### How This Fits Into Onboarding

For new OGP users, the typical first-time federation flow becomes:

1. **User installs OpenClaw** and runs `openclaw gateway start` (local by default)
2. **User wants to connect with someone** — say, a friend who's already running OpenClaw
3. **Agent detects gateway is local** and suggests: "I can expose your gateway publicly so [friend] can connect. Want me to set that up?"
4. **User agrees** → agent runs `ogp-expose setup`
5. **Agent shares the federation URL** with the user to send to their friend
6. **Friend runs** `openclaw federation request --gateway <URL>`
7. **User's agent notifies them** of the inbound request
8. **User approves** → federation established, scheduling flow continues

The tunnel stays active as long as the user wants to federate. When they're done, they can run `ogp-expose stop` to shut it down.

For users who eventually deploy to the cloud (Railway, ECS, etc.), they no longer need the tunnel — they just set `gateway.remote.url` to their deployment URL directly.

### Security Considerations

**Tunnel URLs are public by design.** Anyone who discovers your tunnel URL can attempt to send federation requests to your gateway. This is intentional — it's how the protocol works.

**Protection mechanisms:**
- Federation requests don't grant automatic access — they create a **pending** peer record
- Users must explicitly **approve** each federation request before any intents can be processed
- Approved peers are scoped to specific intents (e.g., `calendar-read` only)
- Nonce-based replay protection prevents message reuse
- Ed25519 signatures prevent message forgery

The risk of exposing a local gateway publicly is mitigated by OGP's trust model: discovery doesn't mean access.

**Tunnel URL rotation:**
- Cloudflare's free "quick tunnels" generate a new random URL each time you start the tunnel
- If you want a stable URL, use a named cloudflared tunnel with a custom domain (advanced setup, not required for basic use)
- Ngrok's free tier also rotates URLs per session

For one-off connections or demos, ephemeral URLs are fine. For long-running federation, deploy to a stable public endpoint.

### Implementation Status

- Skill file created: `~/Documents/GitHub/openclaw-federation/skills/ogp-expose/SKILL.md`
- Config field (`gateway.remote.url`) is already used by the gateway's federation card builder
- Tunnel management is delegated to cloudflared/ngrok CLI tools (no custom networking code required)
- Integration with gateway restart is manual (user confirms restart) to avoid disrupting active sessions

### Future Improvements

- **Auto-restart detection:** Detect if gateway needs restart after config change and offer to do it automatically
- **Persistent tunnel option:** Guide users to set up named cloudflared tunnels with custom domains for stable URLs
- **Tunnel health checks:** Periodically verify tunnel is still active and restart if it dies
- **Built-in tunnel management:** Embed cloudflared as a dependency and manage it directly (avoiding external CLI calls)

For now, the skill provides a working, copy-paste-friendly solution that gets users federating quickly.
