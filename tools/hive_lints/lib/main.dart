import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:hive_lints/src/rules/no_direct_icon_package.dart';
import 'package:hive_lints/src/rules/no_flutter_material_import.dart';
import 'package:hive_lints/src/rules/no_literal_color.dart';
import 'package:hive_lints/src/rules/no_literal_duration.dart';
import 'package:hive_lints/src/rules/no_literal_font_size.dart';
import 'package:hive_lints/src/rules/no_literal_radius.dart';
import 'package:hive_lints/src/rules/no_literal_spacing.dart';
import 'package:hive_lints/src/rules/no_raw_catalog_widget.dart';

/// Top-level analyzer plugin instance discovered by the Dart analysis server.
final plugin = HiveLintsPlugin();

/// Analyzer plugin enforcing Agentic Hive design-system and import rules.
class HiveLintsPlugin extends Plugin {
  @override
  String get name => 'hive_lints';

  @override
  FutureOr<void> register(PluginRegistry registry) {
    registry
      ..registerLintRule(NoLiteralColor())
      ..registerLintRule(NoLiteralSpacing())
      ..registerLintRule(NoLiteralRadius())
      ..registerLintRule(NoLiteralFontSize())
      ..registerLintRule(NoLiteralDuration())
      ..registerLintRule(NoRawCatalogWidget())
      ..registerLintRule(NoDirectIconPackage())
      ..registerLintRule(NoFlutterMaterialImport());
  }
}
