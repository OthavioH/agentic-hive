# widgetbook

Desktop catalog of the Agentic Hive design system for owner review (ADR 0018). It depends only on `design_system`.

```sh
flutter run -d windows   # or linux, macos
```

Addons: theme (Dark default, Light), text scale (1.0 to 2.0) and desktop viewports (Windows, Linux, MacBook Pro).

- **Foundations:** color roles with computed WCAG contrast for every pair, type scale, spacing, radius, elevation, motion (the Flux Motion trial, with a "Reduce motion" knob), icons, and the robot, harness logos and node visual registry.
- **Components:** every catalog component in every variant and state. Hover, focus and pressed states are seeded through a `WidgetStatesController`, so they can be reviewed without a pointer.

## Why the tree is written by hand

ADR 0018 asks for `widgetbook_generator` (`@UseCase` annotations) and allows a manual tree only when the generator cannot resolve in the pub workspace. It cannot (checked 2026-11-20):

- The newest stable `widgetbook_generator` (3.24.0) requires `build ^4.0.0` and `analyzer >=8.2.0 <14.0.0`. The newest prerelease (4.0.0-alpha.4) also requires `build ^4.0.0`.
- The root workspace already resolves `build` 5.0.0 and `analyzer` 14.7.0, because `backend` requires `build_runner ^2.17.1` (2.17.1 depends on `build >=5.0.0 <5.1.0`).
- `flutter pub get` with `build_runner ^2.17.1` and `widgetbook_generator ^3.24.0` fails: "widgetbook_generator >=3.17.0 <4.0.0-alpha.1 depends on build ^4.0.0 and build_runner >=2.17.1 depends on build >=5.0.0 <5.1.0".

The tree lives in `lib/src/directories.dart`. Switch to the generator once a release supports `build` 5 and `analyzer` 14.
