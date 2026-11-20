---
status: accepted
---

# Layer-first, feature-second architecture with a Result type

Both apps split code into layers first and features inside each layer, instead of one folder per feature holding all its layers. The frontend has `domain/<feature>` (entities, repository interfaces, use cases), `data/<feature>` (data sources, transport models, repository implementations) and `presentation/<feature>` (pages, Riverpod controllers, widgets), plus `core/` and `routes/`. The backend keeps its infrastructure folders and adds `domain/<feature>`, `data/<feature>` and `api/<feature>`; its domain services play the role of use cases. Fallible domain operations on both sides return a sealed `Result` with a feature-specific `Failure` hierarchy instead of throwing; exceptions are reserved for bugs.

## Decisions that come with it

- The `shared/` contracts are the domain types both sides agree on and are not duplicated as frontend entities; `data/` converts only transport-specific shapes. `Result` and `Failure` are not contracts and live in each side's `core/`.
- The frontend `domain/` is pure Dart with no Riverpod: data source and repository providers live next to their implementations in `data/`, use case providers in `core/di/`.
- Every UI action goes through a use case, even when it only delegates to a repository; controllers never call repositories.

## Considered options

- **Feature-first folders** (`features/<feature>/{domain,data,presentation}`): keeps a feature together, but the owner preferred one place per layer so layer rules stay easy to see and enforce.
- **Exceptions with `AsyncValue` catching them:** less code, but failures would be invisible in signatures.
