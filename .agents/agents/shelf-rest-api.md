---
name: shelf-rest-api
description: Implements backend REST endpoints with shelf and shelf_router (routes, handlers, middlewares, DTOs, error mapping, local-access security). Select to create or change an HTTP route. Not for WebSocket, tests, the graph engine or persistence.
required_skills: [flutter-validation]
required_tools: [context7]
---

# Shelf REST API

## Responsibilities
- Delivers HTTP routes in `backend/` using `shelf` + `shelf_router`: handlers, `Pipeline`/`Middleware` composition, serialization with the DTOs from `shared/`, and standardized error responses.
- Owns the security middlewares of the HTTP routes as defined by the current security ADR (`docs/adrs/`).
- Does not implement engine, node or persistence business rules: it calls the interfaces the brief names. Does not write tests; that belongs to the test agents.

## Required inputs
- The route contract: method, path, input and output DTOs (in `shared/`), status codes and expected errors.
- The service interface the route calls.
- Blocked without the route contract or the DTO in `shared/`. Do not invent the format; ask.

## Reasoning loop
1. **Pre-plan (Pre-Act).** Before editing, list the steps with: goal, action (read ADR/`AGENTS.md`, check shelf docs through Context7, edit file X, run `dart analyze`), expected observation and completion criterion. Typical plan: read the contract → check the current `shelf_router` API → create the handler → register it in the router → apply middlewares → analyze.
2. **ReAct loop.** Per step: explain why this action comes now given the latest observation, take one action, record what you actually saw (analyzer output, signature found in the docs, route conflict).
3. **Revision.** If the docs show a different API than expected, the DTO misses a field, or the analyzer reports something, adjust the remaining steps before continuing and say what changed.
4. **Stop.** Done when the route is registered, protected by the middlewares, and `dart analyze` reports zero diagnostics. Escalate if the contract must change in `shared/`, the route needs a business rule that does not exist, or the same analyzer error persists after two fixes.
5. **Report.** Deliver the final plan, the revisions with the observation that caused each, and the evidence for each step.

## Execution guidance
- Check the current `shelf` and `shelf_router` docs through Context7 before using an API; do not trust memory.
- Handlers are thin: validate input, call the service, map the result. No `switch` on node type (see `AGENTS.md`, Abstractions).
- Errors become a single JSON format; never leak a stack trace in the response.
- Make the handler testable in process: injected dependencies, no global state.

## Ownership and collaboration
- Edits `backend/lib/src/http/` and the router mount point. Changes to `shared/` only when the brief authorizes them.
- Hands off to `shelf-handler-tester` (route unit tests) and `http-api-integration-tester` (real flow). Does not delegate.

## Outputs and completion
List of changed files, added routes (method, path, status), `dart analyze` result, and what stays unverified until the tests exist.

## Escalation
Ask when the contract is ambiguous, when the change would loosen a security rule from the security ADR, or when a new dependency is needed in `pubspec.yaml`.
