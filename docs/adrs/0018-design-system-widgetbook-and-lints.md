---
status: accepted
---

# Custom design system package, Widgetbook, and first-party analyzer lints

To give Agentic Hive a coherent desktop identity and prevent feature agents from inventing ad-hoc colors, spacing, radii, typography, or raw Material widgets, the UI contract lives in a dedicated `design_system/` Flutter package, is visually reviewed in a standalone `widgetbook/` app, and is mechanically enforced by a first-party analyzer plugin in `tools/hive_lints/`.

## Decisions that come with it

- **`design_system/` package:** Exports semantic `ThemeExtension` tokens (colors, 8-point spacing plus `spaceHalf`, role-based radii, typography roles, elevation, motion), light and dark `ThemeData` builders (dark default), `HiveIcons` (wrapping the free stroke-rounded `hugeicons` set), harness logos and the flat Hive robot SVG fallback, the `NodeVisual` registry contract, `HiveMotion`, and `Hive*` catalog components. `frontend/` depends on `design_system/` and never defines tokens or catalog components locally.
- **Bundled OFL typography:** Display and large numbers use **Bricolage Grotesque**; UI text uses **Geist**; logs and harness output use **Geist Mono**. All font files and their SIL OFL licenses are bundled inside `design_system/`.
- **`widgetbook/` app:** A Flutter desktop app depending only on `design_system/`, using `widgetbook` with `widgetbook_annotation` and `widgetbook_generator` (`@UseCase` annotations next to components; falling back to a manual tree only if the generator cannot resolve in the pub workspace, with the reason recorded). It showcases every token group (with WCAG AA contrast ratios), icons, robot/harness logos, motion, and every component variant and state in light and dark themes.
- **`tools/hive_lints/` analyzer plugin:** Built on Dart's first-party `analysis_server_plugin` package. Enforces `no_literal_color`, `no_literal_spacing`, `no_literal_radius`, `no_literal_font_size`, `no_literal_duration`, `no_raw_catalog_widget`, `no_direct_icon_package`, and `no_flutter_material_import`. Enabled for `frontend/` and disabled in `design_system/` and `widgetbook/` (the token and catalog source). Diagnostics surface in the IDE and in `dart analyze --fatal-infos`.
- **Flux Motion trial:** `HiveMotion` widgets inside `design_system/` wrap `flutter_flux_motion` (0.1.0, single release, imports `package:flutter/material.dart`, no global duration/curve config) using `MaterialUiCompatibilityBridge` where needed, with a dedicated Widgetbook page for owner review. **Exit criteria:** if `flutter_flux_motion` misbehaves on Flutter 3.50, breaks static analysis, or is rejected by the owner in Widgetbook, replace `HiveMotion` internals with standard Flutter animations with zero changes to `frontend/`.

## Considered options

- **`custom_lint` instead of `analysis_server_plugin`:** Rejected because `analysis_server_plugin` is the first-party Dart analyzer plugin mechanism (also used by `riverpod_lint`), integrates directly into `dart analyze --fatal-infos` and IDE analysis without a separate runner, and avoids extra plugin-host divergence.
- **`google_fonts` for typography:** Rejected because runtime font downloading introduces network/offline variability in a local desktop tool; bundling OFL fonts in `design_system/` guarantees deterministic rendering and offline behavior.
- **`Inter` or `Atyp Display` font families:** `Inter` was rejected as the strongest generic AI-generated UI signal; `Atyp Display` was rejected because it is a paid font requiring a commercial app license.
- **Putting tokens and `Hive*` widgets inside `frontend/`:** Rejected because isolating them in `design_system/` enforces a clean package boundary, lets `widgetbook/` depend on `design_system/` without pulling in app state or backend transport, and makes `hive_lints` scoping trivial.

## Consequences

- Feature agents compose screens from `Hive*` components and semantic tokens; missing tokens or components become explicit catalog/token requests to `design-system-builder`.
- `design_system/` is verified by automated WCAG AA contrast tests, behavior widget tests, and Ubuntu-only golden tests (because font rasterization differs across OSes).
- `widgetbook/` must stay buildable in CI, and generated files from `widgetbook_generator` must stay up to date.
