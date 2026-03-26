# OGP Project Intent — Design Document

*Captured 2026-03-23 from David Proctor*

---

## The Vision

Two people working independently — each with their own AI agent — but their agents maintain ambient awareness of what the other has done. Not a shared file system. Not a chat room. An intelligent coordination layer.

The key distinction: **proactive, not reactive.**

- **Reactive (bad):** Stan manually asks "has David done anything with home valuations?" and gets a dump of David's notes.
- **Proactive (good):** Stan asks his agent to start researching home valuations. His agent says: "Sure — but David has already started down this path. He has an Attom API key, a valuation tool in progress, and some notes on Flying Horse neighborhood data. Want me to build on that instead of starting from scratch?"

The agent surfaces relevant context automatically, at the right moment, without Stan having to know to ask.

---

## What This Is NOT

- Not a shared file system (Dropbox, Google Drive)
- Not a group chat (Slack, Teams)
- Not a shared agent (one agent serving both people)
- Not full context sharing (David's .env, private notes, personal preferences don't cross the boundary)

## What This IS

- A **named shared context** that both agents are aware of
- Each agent can **contribute summaries** of their own work into the shared context
- Each agent can **query** the shared context before starting new work
- The shared context is **governed by policy** — you decide what your agent contributes and at what detail level
- **Bidirectional but asymmetric** — David might contribute more detail on real estate tools, Stan might contribute more on backend architecture. Each agent knows to defer to the other in their respective domains.

---

## The `project` Intent

### Structure

A `project` is a named shared context with:
- A unique ID (e.g., `instacrew-collab`)
- A list of participating gateways
- A set of **topics** (areas of knowledge within the project)
- A **contribution log** (timestamped summaries from each participant)
- A **query interface** (structured questions agents can ask each other)

### Intents

```
project.join        — join a named project context
project.contribute  — add a summary/update to a topic
project.query       — ask what a peer has done on a topic
project.status      — get current state of all topics
```

### Example Flow

1. David creates project: `ogp federation request stan contribute-project instacrew-collab`
2. Stan approves, joins
3. David's agent monitors David's work — when David researches Attom API, creates Linear issues, writes notes, it generates a **contribution summary** and posts it to `instacrew-collab` under the `property-data` topic
4. Stan asks his agent to research property data APIs
5. Stan's agent **automatically queries** `instacrew-collab` before starting: "Does anyone in this project have work on property-data?"
6. Stan's agent gets back: "David started this 3 days ago. He has an Attom free trial key (not shared — just noting it exists), has tested against 2 addresses, and is building a valuation tool. Relevant notes: [summary]. Recommendation: coordinate rather than duplicate."
7. Stan's agent surfaces this to Stan before doing any redundant work

---

## The Policy Layer

This is where the doorman matters. David controls what his agent contributes:

```
project: instacrew-collab
  topics:
    property-data:
      contribution_level: summary      # I contribute summaries, not raw notes
      include_api_status: true         # "I have an Attom key" but not the key itself
      include_progress: true           # "70% done" but not the code
      include_blockers: true           # "Attom free tier doesn't include comps" — useful for Stan to know
    personal-finance:
      contribution_level: none         # I don't share anything from this topic
    architecture:
      contribution_level: full         # I trust Stan on arch, he gets full detail
```

Stan configures his own contribution policies independently. Neither side sees the other's raw data — only what they've chosen to contribute.

---

## The "Before You Start" Hook

This is the killer feature. When Stan's agent is about to start a task, it checks the project context first:

```
Before starting: research property data APIs

Checking project context for instacrew-collab...
→ property-data: David has 3 days of work here
  Summary: Evaluated Attom (has free trial), Zillow (too restricted), CoreLogic (enterprise only)
  Status: Attom free tier active, testing valuation tool
  Blocker: Free tier limited to 100 calls/day
  Recommendation: Use David's findings rather than re-evaluating

Stan's agent: "Before I start researching this, David has already done significant work here. 
Do you want me to:
  1. Build on David's Attom integration
  2. Research alternatives David hasn't tried
  3. Start fresh (ignore existing work)
  4. Ask David's agent for a detailed handoff"
```

That's the moment. That's when agents feel like collaborators, not just tools.

---

## The Intent Registry Connection

For `project` intents to work across different gateway implementations (not just OpenClaw), the schema needs to be published. This is where the intent registry matters:

- `registry.ogp.dev` (or similar) publishes the `project.*` intent schemas
- Any OGP-compatible gateway can implement the schema
- MoltPod (agentic economic network) could implement `project.*` on their side and federate with OpenClaw gateways
- The registry is just schemas — no handlers, no code, no centralization of data

---

## Real World Use Cases (Beyond Real Estate)

**Two founders building a startup:**
- Each working on their pitch deck, business plan, market research
- Agents coordinate: "Stan is working on the TAM analysis, David is doing competitive research. Here's what each has found."
- No copying files. No briefing calls. Agents surface the right context at the right time.

**Two engineers on different codebases:**
- David working on OGP package, Stan working on a client that uses OGP
- Stan's agent: "Before you implement the federation request handler, David updated the schema yesterday. Here's the diff summary."

**Two writers collaborating on an article:**
- Each drafting independently
- Agents coordinate: "You're about to write the A2A comparison section. David already wrote a draft of this. Want to see his framing before you write yours?"

---

## What Needs to Be Built

### Phase 1 — Project Primitive (minimal)
- `project.join` and `project.contribute` intents
- Simple JSON store for project context (`~/.ogp/projects/<name>.json`)
- Manual contribution (you tell your agent what to contribute)

### Phase 2 — Agent-Driven Contribution
- Agent monitors daily activity and auto-generates contribution summaries
- BrainLift integration — project contributions draw from your agent's DOK knowledge base
- "Before you start" hook that queries project context before beginning a task

### Phase 3 — Cross-Platform
- Intent schema published to registry
- Other gateway implementations can participate
- MoltPod, Clawporate users, anyone with OGP can join a project context

---

## The Article This Enables

**[Deep Dive] OGP Agent-Comms: When Your AI Agent and Mine Think Together**

Not "my agent messages your agent."
Not "shared file system."

The frame: **ambient coordination between independent agents** — where each agent maintains awareness of what the other has done, surfaces it proactively, and prevents redundant work without either person micromanaging the handoff.

The real estate eval story is the lede. The "before you start" hook is the wow moment. The policy layer is why it's safe. The project intent is what makes it extensible.

---

---

## Implementation Updates (v0.2.9)

### Entry Types vs Topics

The CLI now uses "entry type" terminology instead of "topic" to reduce confusion with agent-comms topics:

```bash
# CLI uses --type flag (--topic is hidden alias for backwards compat)
ogp project contribute instacrew-collab decision "Using Attom for valuations"
ogp project query instacrew-collab --type progress

# Wire format still uses topic field for backwards compatibility
{ "projectId": "instacrew-collab", "topic": "decision", "summary": "..." }
```

### Auto-Registration as Agent-Comms Topics

When you create a project, its ID is automatically registered as an agent-comms topic for all approved peers at `summary` level. This means project members can immediately send agent-comms messages scoped to the project without manual topic configuration:

```bash
# Creating a project auto-registers it as agent-comms topic
ogp project create instacrew-collab "InstaCrew Collaboration"
# → Registers 'instacrew-collab' as topic for all approved peers

# Peers can immediately send project-scoped messages
ogp federation agent stan:18790 instacrew-collab "Any updates on valuation tool?"
```

Similarly, when approving a new peer, all existing local projects are auto-registered as topics for that peer.

### Default-Deny for Unknown Topics

With `off` as a valid response level, you can implement default-deny and only whitelist specific project topics:

```bash
# Set default to deny all unknown topics
ogp agent-comms default off

# Explicitly allow your project topics
ogp agent-comms configure --global --topics "instacrew-collab,personal-tools" --level summary
```

Unknown project topics will receive a cryptographically signed rejection response rather than being silently dropped.

---

*Last updated: 2026-03-26*
*Captured from conversation with David Proctor*
