import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags `TextStyle(fontSize: <literal>)` usages outside the design system.
class NoLiteralFontSize extends AnalysisRule {
  /// Creates a [NoLiteralFontSize] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid literal fontSize values in TextStyle; use design-system '
            'typography tokens instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_literal_font_size',
    'Avoid literal fontSize in TextStyle; use design-system typography '
        'tokens.',
    correctionMessage:
        'Use a text style from the design-system theme or HiveTypography.',
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

  final NoLiteralFontSize rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (constructedTypeName(node) != 'TextStyle') return;

    final element = node.constructorName.type.element;
    if (element != null && !isFlutterElement(element)) return;

    for (final arg in node.argumentList.arguments) {
      if (arg is NamedArgument &&
          arg.name.lexeme == 'fontSize' &&
          isNumericLiteral(arg.argumentExpression)) {
        rule.reportAtNode(arg);
      }
    }
  }
}
