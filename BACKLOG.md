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

## OGP Control UI (OpenClaw Dashboard)
- Add "Federation" section to OpenClaw Control UI (`ui/` in openclaw repo, `feature/federation` branch)
- This is a core gateway feature — not Clawporate-specific
- Anyone running OpenClaw gets it in their gateway dashboard
- Sections:
  - **Peers** — list approved/pending peers, status, last activity, revoke button
  - **Intents** — list registered handlers, add/remove via UI
  - **Activity** — recent federated messages sent/received per peer
  - **Send** — test panel: pick a peer, pick an intent, send a message, see reply
- Rationale: OGP is protocol-level, not platform-level — it belongs in the core UI alongside Channels, Agents, Crons
- Note: Clawporate *may* later add an enterprise-level federation view (cross-user peering visibility) but that is separate from this

## Agentic Negotiation (High Priority — Phase 4)

### The Core Idea
OGP currently uses deterministic handlers (command execution). The next evolution is
**agentic intent handlers** — where the receiving gateway's AI agent evaluates the
request with context and judgment, not just rules.

### Three Levels of Autonomy

| Level | Trigger | Handler | Example |
|---|---|---|---|
| Auto-approve | Within policy | Command handler | Meeting in 9am-11:30am window → book it |
| Agent-negotiated | Outside policy, agent can reason | Agent handler | Meeting at 1pm, agent evaluates context |
| Human-escalated | Agent uncertain, stakes too high | Escalate to human | Agent sends Telegram, waits for approval |

### The Calendar Negotiation Example

```
Stan's agent: calendar-write, 1pm Monday
  + context: { reason: "Rahul requested this sync", priority: "high" }

David's agent (agent handler):
  1. Checks policy: 1pm > 11:30am cutoff → normally reject
  2. Evaluates context: "Rahul" = known trust signal (boss)
  3. Decision: too important to auto-reject, escalate to David
  4. Sends Telegram: "Stan wants 1pm Monday. Context: Rahul requested it. Approve? [Yes] [No] [Suggest alternative]"
  5a. David: "Yes" → booking proceeds
  5b. David: "No" → rejection sent to Stan's agent
  5c. David: "Suggest alternative" → agent proposes 11:00am instead
```

### New Handler Type: `agent`

Add to intent registry alongside `builtin` and `command`:

```json
{
  "handlers": {
    "calendar-write": {
      "type": "agent",
      "policy": {
        "autoApproveWithin": { "start": "09:00", "end": "11:30", "tz": "America/Denver" },
        "escalateWhen": ["outside_window", "high_priority_context"],
        "escalateTo": "telegram:8311956999"
      }
    }
  }
}
```

### Context Passing in OGP Messages

OGP messages already have a `payload` field. Add optional `context` field:

```json
{
  "intent": "calendar-write",
  "payload": { "slot": "2026-03-23T13:00", "duration": 30 },
  "context": {
    "reason": "Rahul requested this sync",
    "priority": "high",
    "requestedBy": "rahul.subramaniam@trilogy.com"
  }
}
```

The receiving agent reads both payload and context when deciding how to handle.

### Why This Matters
- Current OGP: gateway as a secure API
- With agentic handlers: gateway as an intelligent delegate
- The agent knows your preferences, can reason about exceptions, knows when to escalate
- This is what makes it genuinely different from just building an API — the agent applies judgment
- Human stays in the loop on ambiguous cases, not every case

### Trust Signals
Agents should have a way to recognize trust signals in context:
- Known contacts (Rahul = boss, Stan = trusted peer)
- Priority levels
- Organizational context
- Previous patterns ("David always makes exceptions for Rahul")

This is where MEMORY comes in — the agent's memory of past decisions informs future judgment.

### Implementation Notes
- Agent handler type fires a mini agent turn with the intent + context as input
- Agent has access to: policy config, peer record, message context, user memory
- Agent outputs: approve/reject/escalate/counter-propose
- Escalation fires a Telegram message with action buttons
- Timeout on escalation (e.g. 1 hour) → auto-reject if no response
