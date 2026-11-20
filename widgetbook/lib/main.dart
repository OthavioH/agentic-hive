import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/directories.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runApp(const HiveWidgetbook());
}

/// The Agentic Hive design system catalog for owner review.
class HiveWidgetbook extends StatelessWidget {
  /// Creates the catalog.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = WidgetbookTheme<ThemeData>(
      name: 'Dark',
      data: HiveTheme.dark(),
    );
    return Widgetbook(
      directories: directories,
      addons: <WidgetbookAddon>[
        ViewportAddon(const <ViewportData>[
          Viewports.none,
          WindowsViewports.desktop,
          LinuxViewports.desktop,
          MacosViewports.macbookPro,
        ]),
        ThemeAddon<ThemeData>(
          themes: <WidgetbookTheme<ThemeData>>[
            dark,
            WidgetbookTheme<ThemeData>(name: 'Light', data: HiveTheme.light()),
          ],
          initialTheme: dark,
          themeBuilder: (context, theme, child) => Theme(
            data: theme,
            child: HiveSurface(child: child),
          ),
        ),
        TextScaleAddon(min: 1, max: 2, divisions: 4),
      ],
    );
  }
}
