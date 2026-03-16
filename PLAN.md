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
- [ ] Phase 2: Message passing (signed, validated, scoped)
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

**Next steps for Phase 2:**
- Implement message signing with Ed25519 private keys
- Add message validation using peer public keys
- Design and implement message envelope schema
- Add scope validation for message routing
- Implement message delivery to federated gateways
