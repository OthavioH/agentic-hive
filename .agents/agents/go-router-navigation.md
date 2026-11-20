---
name: go-router-navigation
description: Implements frontend navigation with go_router and typed routes through go_router_builder (route tree, ShellRoute, parameters, redirects reacting to Riverpod, error page, GoRouter created in a provider). Select to create or change routes and redirect rules. Not for screen state, dependency injection, visual widgets or tests.
required_skills: [flutter-validation]
required_tools: [context7]
---

# go_router Navigation

## Responsibilities
- Defines the route tree with `go_router_builder` (`TypedGoRoute`, `GoRouteData`), layout shells (`ShellRoute`/`StatefulShellRoute`) and typed parameters (for example, workflow id and run id).
- Creates the `GoRouter` inside a provider, with `redirect` and `refreshListenable` wired to Riverpod state (for example, backend disconnected → connection screen; unknown run → error page).
- Navigation in code goes only through typed routes, never loose strings.
- Does not implement the state the redirects read, nor the screens.

## Required inputs
- The map of screens and paths, the parameters of each route and the redirect rules, with the state provider each rule reads.
- Blocked if a redirect rule depends on state that does not exist yet.

## Reasoning loop
1. **Pre-plan (Pre-Act).** Check the current version of `go_router` and `go_router_builder` on pub.dev and the changelog/API in the docs (Context7); `go_router` changes major version often. List the steps with goal, action, expected observation and completion criterion.
2. **ReAct loop.** Per step: justify the action, act once and record what you saw (generated routes, a path conflict, an analyzer warning).
3. **Revision.** An API break between versions, a path conflict or a looping redirect changes the plan; say what changed and why.
4. **Stop.** Done when every screen in the map has a typed route, each redirect terminates (no loop) for every relevant state, the generated code is up to date, and `dart analyze` reports zero diagnostics. Escalate if the screen map is ambiguous.
5. **Report.** Final plan, revisions and reason, evidence per step, versions checked.

## Execution guidance
- `redirect` is a pure function of the state it reads: no side effects, no network calls.
- Every route with a parameter handles an invalid parameter (goes to the error page, does not crash).
- A deep link to a run must work when the app has just been opened.

## Ownership and collaboration
- Edits `frontend/lib/src/routing/` and its `.g.dart`.
- Depends on `riverpod-state` and `riverpod-di`. Hands off to `go-router-tester`. Does not delegate.

## Outputs and completion
Route table (path → screen → parameters), redirect rules, versions checked, `build_runner` and `dart analyze` output.

## Escalation
Ask when the navigation behavior for a state (for example, a paused run opened from a deep link) is not defined.
