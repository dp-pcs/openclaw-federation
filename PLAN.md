# OpenClaw Agent Federation — Project Plan

## Vision
Two OpenClaw gateways, owned by different people, can exchange structured agent messages
with explicit trust, scoped permissions, and rate controls — without either person relaying.

## Test Environment
- Gateway A: david-proctor.gw.clawporate.elelem.expert (work, cloud ECS)
- Gateway B: localhost / LatentGenius (personal, local)

## Phases
- [ ] Phase 0: Keypair generation + /.well-known/openclaw-federation endpoint
- [ ] Phase 1: Handshake (request / approve / key exchange)
- [ ] Phase 2: Message passing (signed, validated, scoped)
- [ ] Phase 3: Rate limiting + abuse prevention
- [ ] Phase 4: UX + portal integration

## Key Design Decisions
See DESIGN.md

## Status
Started: 2026-03-15
Branch: feature/federation on dp-pcs/openclaw (private)
