import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags `Duration(...)` calls with numeric literal arguments.
class NoLiteralDuration extends AnalysisRule {
  /// Creates a [NoLiteralDuration] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid literal Duration values; use design-system motion tokens '
            'instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_literal_duration',
    'Avoid literal Duration values; use design-system motion tokens.',
    correctionMessage: 'Use a HiveMotion duration token instead.',
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

  final NoLiteralDuration rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (constructedTypeName(node) != 'Duration') return;

    final element = node.constructorName.type.element;
    if (element != null && !(element.library?.isDartCore ?? false)) return;

    for (final arg in node.argumentList.arguments) {
      if (isNumericLiteral(arg.argumentExpression)) {
        rule.reportAtNode(node);
        return;
      }
    }
  }
}
