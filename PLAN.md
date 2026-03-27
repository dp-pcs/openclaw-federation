# OpenClaw Agent Federation — Project Plan

## Vision
Two OpenClaw gateways, owned by different people, can exchange structured agent messages
with explicit trust, scoped permissions, and rate controls — without either person relaying.

## Test Environment
- Gateway A: david-proctor.gw.clawporate.elelem.expert (work, cloud ECS)
- Gateway B: localhost / LatentGenius (personal, local)

## Phases
- [x] Phase 0: Keypair generation + /.well-known/openclaw-federation endpoint
- [x] Phase 1: Handshake (request / approve / key exchange)
- [x] Phase 2: Message passing (signed, validated, scoped)
- [ ] Phase 3: Rate limiting + abuse prevention
- [ ] Phase 4: UX + portal integration

## Key Design Decisions
See DESIGN.md

## Status
Started: 2026-03-15
Branch: feature/federation on dp-pcs/openclaw (private)

### Phase 0 Complete (2026-03-15)
**Implemented:**
- Ed25519 keypair generation using node:crypto
- Keypair persistence to `~/.openclaw/federation-keypair.json` (mode 0600)
- Idempotent `generateOrLoadFederationKeypair(stateDir)` function
- GET `/.well-known/openclaw-federation` endpoint
- Federation card schema with: gatewayId, publicKey, displayName, version, capabilities, rateHints
- Public endpoint (no auth) with CORS headers
- Test suite for keypair generation (idempotency, Ed25519 validation, persistence)

**Files created:**
- `src/gateway/federation/federation-keypair.ts` - Keypair generation and persistence
- `src/gateway/federation/federation-card.ts` - Federation card builder
- `src/gateway/federation/federation-handler.ts` - HTTP handler for /.well-known endpoint
- `src/gateway/federation/federation-keypair.test.ts` - Test suite (4 tests, all passing)

**Integration points:**
- Wired into `server-runtime-state.ts` - keypair generated on gateway startup
- Wired into `server-http.ts` - added as first request stage (before auth)
- Federation card passed to HTTP server via `createGatewayHttpServer` options

**Testing:**
- All tests passing (4/4)
- No type errors in federation code
- Keypair survives restarts (idempotent load from disk)

**Next steps for Phase 1:**
- Design handshake protocol (request/approval flow)
- Implement peer discovery/connection logic
- Add peer key storage and trust management

### Phase 1 Complete (2026-03-16)
**Implemented:**
- Federation peer store with JSON persistence to `~/.openclaw/federation-peers.json` (mode 0600)
- Peer record schema: gatewayId, displayName, gatewayUrl, publicKey, scope, status (pending/approved/rejected), initiatedBy (us/them), timestamps, nonce anti-replay
- POST `/federation/request` endpoint - public, unauthenticated endpoint for inbound federation requests
- POST `/federation/approve` endpoint - public endpoint for receiving approval callbacks from remote gateways
- GET `/federation/peers` endpoint - authenticated, returns list of all peers
- DELETE `/federation/peers/:gatewayId` endpoint - authenticated, revokes a peer
- Request validation: timestamp within ±5 minutes, nonce uniqueness check for replay attack prevention
- System event notifications via heartbeat wake for federation requests and approvals
- CLI commands: `openclaw federation list|request|approve|reject|revoke`
- Federation CLI registered in program subclis with lazy loading

**Files created:**
- `src/gateway/federation/federation-peers.ts` - Peer store with load/save/approve/reject/revoke operations
- `src/gateway/federation/federation-request-handler.ts` - HTTP handlers for /federation/request and /federation/approve
- `src/gateway/federation/federation-peers-handler.ts` - HTTP handlers for authenticated /federation/peers endpoints
- `src/cli/federation-cli.ts` - CLI commands for federation management

**Files modified:**
- `src/cli/program/register.subclis.ts` - Registered federation CLI
- `src/gateway/server-http.ts` - Added federation request/approve/peers endpoints to request pipeline, added stateDir parameter
- `src/gateway/server-runtime-state.ts` - Pass stateDir to HTTP server for federation endpoints

**Integration points:**
- Federation endpoints added as early stages in HTTP request pipeline (after well-known, before hooks)
- Public endpoints (request/approve) use MAX_PREAUTH_PAYLOAD_BYTES limit
- Authenticated endpoints (peers list/revoke) use standard gateway auth + rate limiting
- System events enqueued for owner notification when federation requests arrive
- Heartbeat wake triggered to deliver notifications immediately

**Testing:**
- No type errors in federation code
- All builds passing
- CLI commands accessible via `openclaw federation <command>`

### Phase 2 Complete (2026-03-16)
**Implemented:**
- Ed25519 message signing and verification using node:crypto
- Canonical JSON serialization for deterministic signing (sorted keys, recursive)
- POST `/federation/message` endpoint - public endpoint with signature-based authentication
- POST `/federation/reply/:nonce` endpoint - public endpoint for async message replies
- Message validation: peer approval check, scope verification, timestamp validation (±5 minutes), nonce replay prevention, signature verification
- Intent processing: `ping` (returns gateway status) and `web-search` (DuckDuckGo API)
- Async reply handling via in-memory reply store
- CLI command: `openclaw federation send <gatewayId> --intent <intent> --payload <json>`
- CLI polling for replies with 30-second timeout
- End-to-end test script: `scripts/test-ogp-phase2.sh`

**Files created:**
- `src/gateway/federation/federation-message.ts` - Ed25519 signing/verification with canonical JSON
- `src/gateway/federation/federation-message-handler.ts` - HTTP handlers for /federation/message and /federation/reply/:nonce
- `scripts/test-ogp-phase2.sh` - E2E test script for ping and web-search intents

**Files modified:**
- `src/gateway/server-http.ts` - Added federation message and reply endpoints to request pipeline
- `src/cli/federation-cli.ts` - Added `federation send` command with signing and reply polling

**Integration points:**
- Message endpoint validates all security properties before processing (peer approved, intent in scope, valid timestamp, no replay, valid signature)
- Verification payload excludes signature field for Ed25519 verification
- Reply delivery uses HTTP POST to caller's replyTo URL
- CLI loads keypair from state directory and signs messages with private key
- Reply polling uses in-memory store accessible via getReply/clearReply exports

**Security properties:**
- All messages must be signed with sender's private key
- Signatures verified against stored peer public key
- Intent must be in approved scope for the peer
- Nonce prevents replay attacks (stored per-peer, max 100 recent nonces)
- Timestamp prevents stale messages (±5 minute window)
- 202 Accepted returned immediately, processing happens async

**Testing:**
- No type errors in federation code
- All builds passing
- CLI command available via `openclaw federation send`
- E2E test script validates ping and web-search round-trip

### Phase 3A Complete (2026-03-16)
**Implemented:**
- Intent handler registry with configurable handlers per intent
- Registry file at `{stateDir}/ogp-intent-registry.json` (JSON persistence)
- Handler types: `builtin`, `command`, `skill` (skill type stub for Phase 3B)
- Registry-based dispatch replacing hardcoded switch statement in `processIntent()`
- Command handler type with `{param}` substitution from message payload
- Default registry includes only `ping` builtin handler
- ScopeParams enforcement for peer-specific parameter constraints
- ScopeParams modes: `enforce` (override value), `restrict` (whitelist values), `passthrough` (no constraint)
- Dynamic federation card capabilities based on real registry contents
- CLI commands: `openclaw federation intents`, `openclaw federation register-intent <intent> --command <cmd>`, `openclaw federation remove-intent <intent>`
- Intent registry loaded at gateway startup and passed to federation card builder

**Files created:**
- `src/gateway/federation/federation-intent-registry.ts` - Registry store with load/save/register/remove operations

**Files modified:**
- `src/gateway/federation/federation-message-handler.ts` - Registry-based dispatch, scopeParams enforcement
- `src/gateway/federation/federation-peers.ts` - Added ScopeParamRule and scopeParams field to PeerRecord
- `src/gateway/federation/federation-card.ts` - Accept optional registry, derive capabilities from real handlers
- `src/gateway/server-runtime-state.ts` - Load intent registry at startup, pass to federation card builder
- `src/cli/federation-cli.ts` - Added intent management CLI commands

**Integration points:**
- Registry loaded from disk on every message (allows dynamic updates without restart)
- Command execution uses `execSync` with 10s timeout (sandboxed to registry commands only)
- Command output parsed as JSON if possible, otherwise returned as `{ output: string }`
- ScopeParams applied server-side before intent processing (sender unaware of enforcement)
- Federation card now reflects actual gateway capabilities from registry handlers

**Security properties:**
- Command templates stored in registry, not in message payloads
- Only registry-defined commands can be executed
- Payload values substituted into command template placeholders
- ScopeParams let receiving gateway enforce constraints per peer+intent
- Registry file written with standard permissions (mkdir recursive)

**Testing:**
- No type errors in federation code
- All builds passing
- CLI commands available via `openclaw federation intents/register-intent/remove-intent`

**Next steps for Phase 3B:**
- Implement `skill` handler type (delegate to OpenClaw skills)
- Add intent schema validation (input/output types)
- Implement custom intent definitions with schema
- Add per-peer rate limiting based on approved rate hints
- Add circuit breaker for failing peers
- Add logging and metrics for federation message traffic
