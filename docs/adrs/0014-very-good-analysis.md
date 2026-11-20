---
status: accepted
---

# very_good_analysis with zero tolerance

Every Dart package in the repository (backend, shared, and the frontend when it exists) uses `very_good_analysis` through the root `analysis_options.yaml`, without disabling rules. A change is only done when all three report nothing:

- `dart analyze --fatal-infos` (no errors, warnings or infos);
- `dart format --output=none --set-exit-if-changed .`;
- `dart fix --dry-run` ("Nothing to fix!").

Generated files (`*.g.dart`) are excluded from analysis. CI enforces the three checks on every push and pull request.

## Consequences

- Every public member needs a doc comment (`public_member_api_docs`), including in application code.
- `dart fix` keeps the code on the newest language syntax; for example, it migrated constructors to the Dart 3.14 `new(...)` / `factory name(...)` form.
