import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags direct imports of `package:flutter/material.dart` and
/// `package:flutter/cupertino.dart`.
class NoFlutterMaterialImport extends AnalysisRule {
  /// Creates a [NoFlutterMaterialImport] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid importing package:flutter/material.dart or '
            'package:flutter/cupertino.dart directly.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_flutter_material_import',
    'Avoid importing package:flutter/material.dart or cupertino.dart directly.',
    correctionMessage:
        'Import package:design_system, package:material_ui, or '
        'package:flutter/widgets.dart instead.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final NoFlutterMaterialImport rule;

  static const _disallowedUris = {
    'package:flutter/material.dart',
    'package:flutter/cupertino.dart',
  };

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null && _disallowedUris.contains(uri)) {
      rule.reportAtNode(node);
    }
  }
}
