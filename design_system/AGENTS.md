# design_system/AGENTS.md

Rules for the custom design system package (`design_system/`). The root `AGENTS.md` still applies; where this file conflicts with it, this file wins inside `design_system/`. See ADR 0018 for the rationale behind the package, Widgetbook, and `hive_lints`.

## Scope and Exports

`design_system/` is a pure Flutter UI package that depends on nothing else in the repository. It exports:

- Semantic tokens (`ThemeExtension`s) and light/dark `ThemeData` builders (dark is default)
- `Hive*` catalog components
- `HiveIcons` (icons and harness logos) and the flat Hive robot SVG fallback
- `NodeVisual` registry contract
- `HiveMotion` widgets (isolating the Flux Motion trial)

Bundled fonts and SVG assets live inside `design_system/`; never use `google_fonts` or runtime font downloads.

## UI Contract (Tokens)

Features read tokens through context accessors and never pass literal colors, spacing, radii, font sizes, or durations.

### Color Roles

Expose colors only as semantic roles (with `on*` foreground pairs where applicable):

- Surfaces & structure: `background`, `surface1`, `surface2`, `surface3`, `borderSubtle` (1px hairline)
- Primary action & active item only: `accent`, `onAccent`
- Secondary green & status: `accentMuted` (green family for charts, success, running), `success`, `warning`, `danger`, `info` (desaturated, each with an `on*` color)
- Node statuses: `statusIdle`, `statusRunning`, `statusPaused`, `statusFailed`, `statusSucceeded`
- Charts: categorical palette

Starting palette (pending owner approval in Widgetbook; must pass WCAG AA contrast tests):
- **Dark (default):** `background` `#050706` (near black); surfaces as dark green-grey steps starting `#0E1210`, `#161B18`, `#1F2622`; `accent` lime `#C6EF4E` with `onAccent` near black; green family from lime to forest green.
- **Light:** surfaces `#F6F7F7` and `#EAECDF`, same accent, foreground near black.

### Spacing

8-point scale only: `space1` (8), `space2` (16), `space3` (24), `space4` (32), `space5` (40), `space6` (48), `space8` (64), plus `spaceHalf` (4) **only** for tight inner gaps (e.g., icon to text inside a badge or chip). No other spacing values.

### Radius by Role

Two components with the same role share one radius:

- `radiusPill`: full pill/circle for buttons, inputs, chips, badges, nav items, avatars
- `radiusCard`: `24` for cards
- `radiusPanel`: `32` for large containers, dialogs, and the side rail

### Typography Roles

- **Display & large numbers:** `Bricolage Grotesque`
- **UI text (title, body, label):** `Geist`
- **Logs & harness output:** `Geist Mono`

Sizes and line heights follow the 4/8 rhythm. Confirm SIL OFL licenses before bundling and keep the license files in `design_system/`.

### Elevation & Motion

- **Elevation:** Prefer surface steps plus 1px hairline borders (`borderSubtle`); at most two small layered shadow tokens.
- **Motion:** Duration tokens (`short`, `medium`, `long`) and curve tokens (`standard`, `emphasized`, `exit`). Every motion widget must respect `MediaQuery.disableAnimations`.
- **Flux Motion trial:** `HiveMotion` (fade in, slide in, stagger, page transition) passes motion tokens into `flutter_flux_motion`. `flutter_flux_motion` may **only** be imported inside `design_system/` (wrapped in `MaterialUiCompatibilityBridge` where needed). Exit criteria: if it misbehaves on Flutter 3.50, breaks analysis, or the owner rejects it in Widgetbook, replace `HiveMotion` internals with standard Flutter animations with zero feature changes.

## Icons, Logos & Node Visuals

- **`HiveIcons`:** Wraps the free `hugeicons` package (MIT), stroke rounded style only. Never use `hugeicons_pro` or paid icons. Features never import `hugeicons` directly.
- **Harness logos:** Use the Hugeicons free logo when available; otherwise use the official SVG from the company's press/brand kit after verifying brand guidelines; when guidelines forbid it, fall back to the Hive robot. Expose logos only as `HiveIcons.harness<Name>`.
- **Hive robot SVG:** One flat custom SVG drawn in token colors (no 3D, no glossy mascot), used as the fallback agent face.
- **Node visual registry:** `design_system/` defines `NodeVisual` (icon, label key, optional accent) and rendering widgets (`HiveAgentAvatar` with status). Each node type registers its visual; never `switch` on node type.

## Initial Catalog & Desktop Profile

Initial components: `HiveSideRail` (floating pill, collapsed by default, expandable with labels, Hive hexagon mark on top, active item as filled circle, the only subtle green→black vertical gradient in the app on its background), `HiveRailItem`, `HivePageHeader`, `HiveEmptyState`, `HiveButton` (primary/accent, secondary, ghost; sizes; hover, focus, pressed, disabled, loading), `HiveIconButton` (circular), `HiveCard`, `HiveBadge`, `HiveStatusDot` (shape per status, not only color), `HiveAgentAvatar`, `HiveConnectionIndicator`, `HiveHexMark`.

F2 additions (#10): `HiveTextField` (pill) and `HiveTextArea` (`radiusCard`, optional `mono`) over one shared input frame; `HiveChip.removable` / `HiveChip.filter`; `HiveSegmentedControl`; `HiveConfirmDialog` + `showHiveConfirmDialog` (`radiusPanel`, `background` scrim at `scrimOpacity`); `HiveBanner` (inline) and `HiveToast` + `showHiveToast` (transient), both toned by `HiveFeedbackTone`; `HiveMarkdownView` (`package:markdown`, raw HTML shown as text); `HiveMasterDetail`; `HiveCollapsibleSection`. `HiveButtonVariant.danger` is only for confirming a destructive action inside a confirmation. Selected segments and filter chips use the inverse pair (`background` on `onSurface`); feedback tones color only borders and icons, never text, and are tested as UI (3:1) on every surface.

**Desktop platform profile:** Windows, Linux, and macOS; mouse + keyboard first. Every interactive component must have a hover state, a visible keyboard focus indicator, and a semantics label. Support desktop density (sidebar, multi-column, master-detail).

## Do and Don't

**Do**
- Near-black backgrounds with dark green-grey surface steps and hairline borders; one lime accent for the primary action and active item only.
- Rounded everything: pills and circles for controls, 24 for cards, 32 for panels.
- 8-point rhythm; `spaceHalf` only inside small controls.
- Clear hierarchy per screen: one primary action, one focal number or element; vary card sizes and density by importance.
- Large display numbers in Bricolage Grotesque for metrics; Geist for UI; Geist Mono for logs.
- Minimal stroke-rounded icons from `HiveIcons`.
- Harness logos as agent faces; the robot only as fallback.
- Status by shape plus color; WCAG AA contrast measured on composed colors.
- Real product labels and realistic long-text and empty cases.
- Desktop density: sidebar, multi-column, and master-detail layouts; hover and focus states on every interactive element.

**Don't**
- No purple, indigo, or blue-to-purple gradients; no decorative gradients anywhere except the single subtle green→black side rail background.
- No `Inter` as a font.
- No glassmorphism, blur panels, glow halos, 3D blobs, or floating decorative shapes.
- No ✨ sparkle icon as an "AI" marker; the brand mark is the Hive hexagon.
- No emoji as icons; no cute 3D robot mascots (the robot is flat and only a fallback).
- No large diffuse shadows.
- No mixed radii within one role; no square cards beside pill buttons.
- No literal colors, spacing, radii, font sizes, or durations outside the design system.
- No hero-plus-three-equal-cards layouts; no uniform spacing without hierarchy.
- No mobile layouts stretched across desktop.
- No lorem ipsum, "John Doe", or invented copy in delivered states.
- No ad-hoc accent colors per screen.

## Widgetbook Rules

- `widgetbook/` depends only on `design_system/`. Use `@UseCase` next to components with `widgetbook_annotation` / `widgetbook_generator` (fall back to a manual tree only if the generator cannot resolve in the workspace, and record why).
- Include theme (light/dark), text scale, and desktop viewport addons.
- Every catalog component must have use cases for **every variant and state**.
- Every token group must have a showcase page: colors (with contrast ratios), type scale, spacing, radius, elevation, motion (including the Flux Motion trial), icons, the robot, and harness logos.

## Catalog & Token Requests

Feature agents never invent local tokens or catalog-level widgets. When a feature needs a new token or `Hive*` component, record it in a **Catalog requests** section of the feature spec or file an issue for `design-system-builder`.

## Enforcement Gates

- **`hive_lints`:** Enabled in `frontend/`, disabled in `design_system/` and `widgetbook/`.
- **WCAG AA contrast:** Automated tests verify every foreground/background token pair in both light and dark themes.
- **Goldens & behavior:** Golden tests for every catalog component in light and dark run on **Ubuntu CI only**; behavior widget tests cover stateful components (`HiveSideRail`, `HiveButton`, focus, semantics).
- **Zero tolerance (ADR 0014):** `dart analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed .`, and `dart fix --dry-run` must all report nothing.
