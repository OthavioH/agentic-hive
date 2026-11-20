import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags literal `Color(...)`, `Color.from...`, and `Colors.*` usages outside
/// the design system.
class NoLiteralColor extends AnalysisRule {
  /// Creates a [NoLiteralColor] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid literal Color values and Material Colors; use design-system '
            'color tokens instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_literal_color',
    'Avoid literal Color values or Material Colors.',
    correctionMessage:
        'Use a design-system color token (for example, context.hiveColors) '
        'instead.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodInvocation(this, visitor)
      ..addPrefixedIdentifier(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final NoLiteralColor rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (constructedTypeName(node) != 'Color') return;
    final element = node.constructorName.type.element;
    if (element == null || isDartUiElement(element)) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is! Identifier || target.name != 'Color') return;
    final element = target.element;
    if (element == null || isDartUiElement(element)) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix;
    if (prefix.name != 'Colors' && prefix.name != 'CupertinoColors') return;
    final element = prefix.element;
    if (element == null || isFlutterElement(element)) {
      rule.reportAtNode(node);
    }
  }
}
