# OGP Backlog — Post-MVP Enhancements

Ideas captured during development. Don't touch until MVP is working end-to-end.

---

## Handshake / Trust

- **Scope editor on accept** — when receiving a federation request, allow the receiving party to counter-propose a narrower scope before accepting (currently: accept locks in requester's proposed scope)
- **Scope renegotiation** — allow either party to modify scope on an existing relationship without full re-handshake
- **Multi-scope tiers** — separate scopes per intent category (e.g. "calendar: read-only" vs "calendar: read-write") rather than a flat list
- **Time-limited federation** — set expiry at approval time (e.g. "Stan gets access for 30 days, then auto-expires")
- **Project-tagged scopes** — tie scope to a project tag; revoking the project revokes all associated scope automatically

## Discovery

- **Federation address book** — `openclaw federation add-contact stan --gateway https://stanislav-huseletov.gw.clawporate.elelem.expert` so you don't have to remember URLs
- **QR code pairing** — scan a QR code to initiate federation request (same UX as device pairing)
- **Clawporate portal directory** — opt-in org directory: "show my gateway address to other Clawporate users"

## Security / Abuse Prevention

- **Per-peer token bucket rate limiting** — cap requests per hour per peer independently of global policy
- **Cost estimation gate** — estimate LLM token cost before executing federated request; reject if over threshold
- **Abuse detection** — auto-pause peer if they send 3x their normal rate in a 10-minute window; alert owner
- **Concurrent request cap** — max N federated requests executing simultaneously per peer
- **Scope intent whitelist** — federated messages must declare intent upfront; hard-reject anything not on approved list before any LLM call

## UX / Notifications

- **Clawporate portal federation tab** — UI showing peers, scope, usage stats, revoke button
- **"My federation address" on portal workspace page** — easy copy of your gateway URL for sharing
- **Revocation notification** — when either party revokes, both get a Telegram notification
- **Federation activity log** — running log of all federated messages sent/received per peer

## Protocol

- **OGP version negotiation** — gateways on different OGP versions negotiate down to lowest common supported version
- **Capability matching** — before sending a request, check if the target gateway's capabilities include what you need
- **Async reply pattern** — structured replyTo callback for long-running federated tasks (currently Phase 2)
- **Message receipts** — acknowledgement that a federated message was received and queued (not just HTTP 200)

## Real-world Use Cases (to build demos around)

- **Meeting scheduler** — David's agent proposes slots, Stan's agent checks his calendar, responds with availability, both calendars get updated
- **Project status request** — ask a peer's agent for a summary of a shared GitHub repo
- **Shared task handoff** — assign a task to a peer's agent and get notified on completion
