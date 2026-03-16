# OGP Phase 3 — Intent Taxonomy, Handler Registry & Real Capabilities

## Goal
Transform OGP from a protocol demo into a real capability exchange platform.
Phase 3 introduces a standard intent taxonomy, a configurable handler registry,
per-peer parameter enforcement, rate limiting, and the `ogp-intent` skill.

---

## Phase 3A — Intent Taxonomy + Handler Registry

### Standard Intent Taxonomy (OGP v0.1)

| Intent | Description | Input | Output |
|---|---|---|---|
| `ping` | Liveness check | `{}` | `{status, gatewayId, ts}` |
| `calendar-read` | Get free/busy slots | `{range, duration, tz?}` | `{available: [slots], tz}` |
| `calendar-write` | Create an event | `{slot, title, attendees?, notes?}` | `{eventId, status}` |
| `web-search` | Search the web | `{query, limit?}` | `{results: [{title, url, snippet}]}` |
| `issue-list` | List open issues/tickets | `{project?, limit?, status?}` | `{issues: [{id, title, status, assignee}]}` |
| `issue-get` | Get a specific issue | `{id}` | `{id, title, status, description, assignee}` |
| `note-create` | Create a note | `{title, content, folder?}` | `{noteId, status}` |
| `note-search` | Search notes | `{query}` | `{notes: [{title, snippet, id}]}` |
| `send-message` | Send a message | `{channel, target, text}` | `{status, messageId?}` |
| `task-create` | Create a task | `{title, notes?, due?}` | `{taskId, status}` |

`ping` is built-in and always works. All others require a configured handler.

### Handler Registry

Each gateway has a local `ogp-intent-registry.json` in state dir:

```json
{
  "version": "1.0",
  "handlers": {
    "ping": { "type": "builtin" },
    "calendar-read": {
      "type": "command",
      "command": "gws calendar freebusy --range {range} --duration {duration}"
    },
    "web-search": {
      "type": "command",
      "command": "brave-search {query}"
    },
    "issue-list": {
      "type": "command",
      "command": "mcporter call linear list_issues --project {project}"
    }
  },
  "custom": {
    "sprint-health": {
      "description": "Custom sprint health check",
      "input": { "project": "string" },
      "output": { "health": "string", "openIssues": "number" },
      "command": "~/scripts/sprint-health.sh {project}"
    }
  }
}
```

Handler types:
- `builtin` — handled in code (ping)
- `command` — shell command with `{param}` substitution
- `skill` — invoke an OpenClaw skill

### scopeParams — Per-Peer Parameter Enforcement

When approving a peer, you can enforce or restrict parameters:

```json
"peers": {
  "gw:joe@company.com": {
    "scope": ["issue-list"],
    "scopeParams": {
      "issue-list": {
        "project": { "mode": "enforce", "value": "project-j" }
      }
    }
  },
  "gw:bob@company.com": {
    "scope": ["issue-list"],
    "scopeParams": {
      "issue-list": {
        "project": { "mode": "restrict", "allowed": ["project-b", "project-b-archive"] }
      }
    }
  }
}
```

Modes:
- `enforce` — always override with this value, ignore what peer sends
- `restrict` — peer can only send values from the allowed list
- `passthrough` — peer can send any value (default)

### Federation Card Update

Gateway card now includes only intents with configured handlers:

```json
{
  "gatewayId": "gw:david.proctor@trilogy.com",
  "capabilities": ["ping", "calendar-read", "web-search", "issue-list", "sprint-health"],
  ...
}
```

---

## Phase 3B — Rate Limiting + Abuse Prevention

- Per-peer token bucket (default 10 req/hour)
- Global policy cap in `openclaw.json`
- Spike detection → auto-pause + notify owner
- Concurrent request cap (max 2 per peer)
- `federation unpause <gatewayId>` CLI command

---

## Phase 3C — Real Intent Handlers

Wire up actual implementations for standard intents:
- `calendar-read` → gws/gog Google Calendar freebusy
- `web-search` → Brave Search API
- `issue-list` → mcporter Linear/Jira
- `ping` → already works

---

## Phase 3D — `ogp-intent` Skill

Interview-based skill for creating and sharing custom intents.

Flow:
1. Maps intent to standard taxonomy or creates custom
2. Prompts for handler command
3. Prompts for per-peer scopeParams
4. Registers in `ogp-intent-registry.json`
5. Outputs export snippet (JSON) to share with peers

Export snippet format:
```json
{
  "ogp-intent": "sprint-health",
  "version": "1.0",
  "schema": {
    "input": { "project": "string" },
    "output": { "health": "string", "openIssues": "number" }
  },
  "description": "Returns sprint health metrics for a project"
}
```

Import: `openclaw federation import-intent <file.json>` adds intent to local registry
so your gateway understands what the intent means when a peer sends it.

---

## Phase 3E — Meeting Scheduling Demo (end-to-end)

**The flagship use case:**

```
David: "Find a 30-minute meeting with Stan next week"

Junior → OGP message to Stan's gateway:
  intent: "calendar-read"
  payload: { range: "next week", duration: 30 }

Stan's gateway: reads his Google Calendar → returns available slots

Junior: "Stan is free Monday 3pm, Tuesday 10am. Which works?"
David: "Monday 3pm"
Junior: creates event on both calendars
```

Zero human relay. This is the proof the protocol is real.

---

## Build Order

1. **3A** — Intent registry, handler dispatch, scopeParams, card update
2. **3B** — Rate limiting
3. **3C** — Real handlers (calendar, search)
4. **3D** — ogp-intent skill
5. **3E** — Meeting demo end-to-end

---

## What Doesn't Change

- Ed25519 signing/verification (Phase 2) — unchanged
- Peer store + approval flow (Phase 1) — unchanged
- Well-known endpoint (Phase 0) — extended with richer capabilities list
