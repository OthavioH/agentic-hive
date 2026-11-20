# frontend/AGENTS.md

Rules for the Flutter desktop app. The root `AGENTS.md` still applies; where this file conflicts with it, this file wins inside `frontend/`.

The Flutter project has not been created yet. Stack decisions: Riverpod for state and dependency injection, go_router with typed routes (see `docs/adrs/0010-frontend-riverpod-and-go-router.md`).

## Material and Cupertino are packages, not part of the SDK

Material and Cupertino were moved out of the Flutter framework into standalone packages published by flutter.dev: `material_ui` and `cupertino_ui`. This project starts on them directly.

- Import `package:material_ui/material_ui.dart` and `package:cupertino_ui/cupertino_ui.dart`.
- Never import `package:flutter/material.dart` or `package:flutter/cupertino.dart`.
- Localizations: take `GlobalMaterialLocalizations` and `GlobalCupertinoLocalizations` from `material_ui` and `cupertino_ui`, not from `flutter_localizations`.
- If a third-party package still imports `package:flutter/material.dart`, wrap the app (through `MaterialApp.builder`) or the affected subtree in `MaterialUiCompatibilityBridge`. Prefer a maintained alternative package first.
- Code copied from older examples or tutorials uses the old imports. Migrate it with:

  ```
  dart fix --apply --code=migrate_design_widgets
  ```

  This rewrites `package:flutter/material.dart` imports to `package:material_ui/material_ui.dart` and adds the dependency.

Versions on 2026-11-20: `material_ui` 1.11.1 and `cupertino_ui` 1.1.7, both requiring Flutter >= 3.47.0. Check pub.dev for the current version before adding them (root `AGENTS.md`, latest stable versions rule).
