---
name: shelf-websocket
description: Implements the backend WebSocket channel with shelf_web_socket (upgrade, authentication, the shared/ event protocol, connection lifecycle, run event broadcast, ping and reconnection). Select to create or change real-time communication with the frontend. Not for REST routes, tests or engine logic.
required_skills: [flutter-validation]
required_tools: [context7]
---

# Shelf WebSocket

## Responsibilities
- Delivers the WebSocket endpoint in `backend/` with `shelf_web_socket` (`webSocketHandler`, with `allowedOrigins` and `pingInterval`).
- Implements the message protocol defined in `shared/`: server events (node progress, pause, run end) and client commands (approve, reject, answer `ask_human`, cancel).
- Owns the lifecycle: authentication on upgrade, connection registration and removal, per-run broadcast, clean disconnection without leaking `Stream` subscriptions.
- Does not implement the engine or persistence; it consumes the event stream they expose.

## Required inputs
- The message contract in `shared/` (types, fields, versioning) and the engine's event source.
- Blocked without the message contract. Do not invent event types.

## Reasoning loop
1. **Pre-plan (Pre-Act).** List the steps with goal, action, expected observation and completion criterion. Typical plan: read the message contract → check the `shelf_web_socket` API through Context7 → authenticate on upgrade → register the connection → wire the event stream → handle commands → clean up on disconnect → analyze.
2. **ReAct loop.** Per step: justify the action from the latest observation, act once and record what you saw (callback signature in the docs, analyzer output, a stream subscription still open).
3. **Revision.** If the docs diverge, a message type is missing, or a subscription leak shows up, redo the remaining steps and say why.
4. **Stop.** Done when the upgrade enforces authentication, rejects a disallowed `Origin`, delivers events to the right run, cancels subscriptions on disconnect, and `dart analyze` reports zero diagnostics. Escalate if the protocol needs a new message in `shared/` or the engine does not expose the needed events.
5. **Report.** Final plan, revisions with the observation that caused them, and evidence for each step.

## Execution guidance
- Check the current docs through Context7; the callback receives `(WebSocketChannel, String? subprotocol)`.
- `allowedOrigins` only filters connections that carry an `Origin` header; the authentication required by the security ADR still applies to clients without `Origin`.
- Messages are JSON with a type field and a version; answer an unknown message with an explicit error, without dropping the connection.
- The frontend can drop and come back: on reconnect, it must be able to request the current run state instead of relying on lost events.

## Ownership and collaboration
- Edits `backend/lib/src/ws/` and the handler mount point. Changes to `shared/` only when the brief authorizes them.
- Hands off to `shelf-handler-tester` and `websocket-integration-tester`. Does not delegate.

## Outputs and completion
Changed files, supported messages (in and out), authentication rules applied, `dart analyze` result, and what is still untested.

## Escalation
Ask when the message contract is ambiguous, when `shared/` must change, or when the change would loosen authentication.
