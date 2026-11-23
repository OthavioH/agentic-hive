import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Wraps [child] in a themed [MaterialApp] + [HiveSurface] for widget tests.
Widget hiveTestApp({
  required Widget child,
  ThemeData? theme,
  NodeVisualRegistry? registry,
}) {
  final content = registry == null
      ? child
      : NodeVisualScope(registry: registry, child: child);

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? HiveTheme.dark(),
    home: Scaffold(body: HiveSurface(child: content)),
  );
}

/// Loads the bundled `BricolageGrotesque`, `Geist`, and `GeistMono` fonts
/// into Flutter's [FontLoader] so golden tests render real typography.
Future<void> loadHiveFonts() async {
  const fonts = <String, String>{
    'BricolageGrotesque':
        'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
    'Geist': 'assets/fonts/geist/Geist-Variable.ttf',
    'GeistMono': 'assets/fonts/geist_mono/GeistMono-Variable.ttf',
  };

  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
