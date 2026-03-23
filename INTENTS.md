# OGP Standard Intents

This document specifies the standard intents supported by OGP-compliant gateways.

## Intent Structure

Every OGP message includes an `intent` field that identifies the operation type:

```json
{
  "intent": "message",
  "from": "peer-alice:18790",
  "to": "peer-bob:18790",
  "nonce": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-23T10:30:00Z",
  "payload": { ... }
}
```

## Core Intents

### message

Simple text message between gateways.

**Payload Schema:**
```json
{
  "type": "object",
  "properties": {
    "text": { "type": "string" }
  },
  "required": ["text"]
}
```

**Example:**
```json
{
  "intent": "message",
  "payload": {
    "text": "Hello from Alice's gateway!"
  }
}
```

---

### task-request

Request a peer to perform a task.

**Payload Schema:**
```json
{
  "type": "object",
  "properties": {
    "taskType": { "type": "string" },
    "description": { "type": "string" },
    "parameters": { "type": "object" }
  },
  "required": ["taskType", "description"]
}
```

**Example:**
```json
{
  "intent": "task-request",
  "payload": {
    "taskType": "analysis",
    "description": "Analyze the Q1 sales report",
    "parameters": {
      "format": "summary",
      "maxLength": 500
    }
  }
}
```

---

### status-update

Status update from a peer.

**Payload Schema:**
```json
{
  "type": "object",
  "properties": {
    "status": { "type": "string" },
    "message": { "type": "string" }
  },
  "required": ["status"]
}
```

**Example:**
```json
{
  "intent": "status-update",
  "payload": {
    "status": "completed",
    "message": "Analysis finished, results attached"
  }
}
```

---

## Agent Communication Intent (v0.2.0)

### agent-comms

Agent-to-agent communication with topic routing, priority levels, and reply support.

**Payload Schema:**
```json
{
  "type": "object",
  "properties": {
    "topic": {
      "type": "string",
      "description": "Topic category for routing"
    },
    "message": {
      "type": "string",
      "description": "The message content"
    },
    "priority": {
      "type": "string",
      "enum": ["low", "normal", "high"],
      "description": "Message priority level"
    }
  },
  "required": ["topic", "message"]
}
```

**Message-Level Fields:**
```json
{
  "intent": "agent-comms",
  "replyTo": "https://sender.example.com/federation/reply/nonce-123",
  "conversationId": "conv-456",
  "payload": { ... }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `replyTo` | string (URI) | Callback URL for async reply |
| `conversationId` | string | Thread identifier for multi-turn conversations |

**Example:**
```json
{
  "intent": "agent-comms",
  "from": "stan:18790",
  "to": "david:18790",
  "nonce": "abc-123",
  "timestamp": "2026-03-23T10:30:00Z",
  "replyTo": "https://stan.example.com/federation/reply/abc-123",
  "conversationId": "memory-discussion-001",
  "payload": {
    "topic": "memory-management",
    "message": "How do you persist context across sessions?",
    "priority": "normal"
  }
}
```

**Topic Restrictions:**

The receiving gateway can restrict which topics a peer is allowed to use:

```json
{
  "intent": "agent-comms",
  "enabled": true,
  "topics": ["memory-management", "task-delegation"]
}
```

Messages with topics not in the allowed list receive `403 Forbidden`.

**Reply Mechanism:**

1. **Callback** (preferred): Receiver POSTs to `replyTo` URL
2. **Polling** (fallback): Sender polls `GET /federation/reply/:nonce`

---

## Custom Intents

Gateways can register custom intents beyond the standard set. Custom intents should:

1. Use a namespaced name (e.g., `myorg.calendar-read`)
2. Define a JSON schema for the payload
3. Be documented in the gateway's capabilities

**Registration (CLI):**
```bash
ogp intent register calendar-read \
  --description "Read calendar availability" \
  --schema '{"type":"object","properties":{"date":{"type":"string"}}}'
```

Custom intents appear in the gateway's federation card under `capabilities.intents`.

---

## Error Responses

| Status | Meaning | Example |
|--------|---------|---------|
| 400 | Invalid payload | Missing required field |
| 401 | Invalid signature | Signature verification failed |
| 403 | Scope denied | Intent not in granted scope |
| 403 | Topic denied | Topic not allowed for agent-comms |
| 429 | Rate limited | Exceeded requests/window |

**Error Response Format:**
```json
{
  "success": false,
  "nonce": "abc-123",
  "error": "Intent 'calendar-read' not in granted scope",
  "statusCode": 403
}
```

**Rate Limit Response:**
```json
{
  "success": false,
  "nonce": "abc-123",
  "error": "Rate limit exceeded for intent 'agent-comms'",
  "statusCode": 429,
  "retryAfter": 42
}
```
