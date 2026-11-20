import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags raw Material widgets where a `Hive*` design-system catalog widget
/// exists.
class NoRawCatalogWidget extends AnalysisRule {
  /// Creates a [NoRawCatalogWidget] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid raw Material widgets when a Hive* design-system catalog '
            'widget exists.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_raw_catalog_widget',
    'Avoid raw Material widgets; use the corresponding Hive* catalog widget.',
    correctionMessage:
        'Replace with the matching Hive* widget from package:design_system.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final NoRawCatalogWidget rule;

  static const _disallowedWidgets = {
    'ElevatedButton',
    'FilledButton',
    'OutlinedButton',
    'TextButton',
    'IconButton',
    'Card',
    'Chip',
    'Badge',
    'TextField',
    'TextFormField',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = constructedTypeName(node);
    if (!_disallowedWidgets.contains(typeName)) return;

    final element = node.constructorName.type.element;
    if (element == null || isFlutterElement(element)) {
      rule.reportAtNode(node.constructorName);
    }
  }
}
