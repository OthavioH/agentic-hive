# design_system

The Agentic Hive design system: semantic tokens, light and dark themes, the `Hive*` catalog, `HiveIcons`, the node visual registry and `HiveMotion`. Rules live in [`AGENTS.md`](AGENTS.md); the decision is ADR 0018.

## Use it

```dart
import 'package:design_system/design_system.dart';

MaterialApp(theme: HiveTheme.light(), darkTheme: HiveTheme.dark(), themeMode: ThemeMode.dark);

final colors = context.hiveColors;      // semantic color roles
final spacing = context.hiveSpacing;    // spaceHalf … space8
final radii = context.hiveRadii;        // radiusPill, radiusCard, radiusPanel
final type = context.hiveTypography;    // number, display, title, body, label, mono
final elevation = context.hiveElevation; // hairline, focusRingWidth, two shadows
final motion = context.hiveMotion;      // short/medium/long + curves
```

`HiveColors.contrastPairs` lists every foreground/background pair with its WCAG AA level, for the contrast tests and the Widgetbook color page.

## Fonts

All three families are variable fonts from `google/fonts` `ofl/`, bundled with their licenses (SIL Open Font License 1.1, confirmed 2026-11-20):

| Role | Family | File | License |
|---|---|---|---|
| Display, numbers | Bricolage Grotesque | `assets/fonts/bricolage_grotesque/` | `OFL.txt` |
| UI | Geist | `assets/fonts/geist/` | `OFL.txt` |
| Logs | Geist Mono | `assets/fonts/geist_mono/` | `OFL.txt` |

Typography styles set the `wght` font variation next to `fontWeight`, because the files are variable fonts.

## Harness logos

| Token | Source |
|---|---|
| `HiveIcons.harnessClaudeCode` | Hugeicons free `strokeRoundedClaude` |
| `HiveIcons.harnessCodex` | Hugeicons free `strokeRoundedChatGpt` (OpenAI mark) |
| `HiveIcons.harnessGeminiCli` | Hugeicons free `strokeRoundedGoogleGemini` |
| `HiveIcons.harnessAntigravity` | Same glyph as Gemini CLI (owner decision, 2026-11-20). Hugeicons has no Antigravity logo; Google's press kit exists but Google lists product icons as "ask first", so it is not bundled. |
| `HiveIcons.harnessTerminal` | The Hive robot (`assets/svg/hive_robot.svg`) |

## Flux Motion trial

`HiveFadeIn`, `HiveSlideIn`, `HiveStagger`, `HiveMotion.route` and `HivePageTransition` pass motion tokens into `flutter_flux_motion` 0.1.0 specs. Only `lib/src/motion/hive_motion.dart` imports it.

Status on Flutter 3.50.1: works, analysis clean. The widgets used (`FluxFade`, `FluxSlide`, `FluxStagger`, `FluxPageRoute`) only need `flutter/widgets`, so `MaterialUiCompatibilityBridge` is not needed (it is also `@Deprecated`, which would fail `--fatal-infos`). Flux exposes its page transition only through `FluxPageRoute`, so `HivePageTransition` reuses that route's `transitionsBuilder` for router pages such as go_router's `CustomTransitionPage`.
