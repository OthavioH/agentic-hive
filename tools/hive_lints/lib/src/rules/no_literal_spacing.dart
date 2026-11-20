import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags numeric literal spacing values in `EdgeInsets`,
/// `EdgeInsetsDirectional`, `SizedBox` gaps, and `Gap`-like widgets.
class NoLiteralSpacing extends AnalysisRule {
  /// Creates a [NoLiteralSpacing] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid numeric literal spacing in EdgeInsets, SizedBox, and Gap '
            'widgets; use design-system spacing tokens instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_literal_spacing',
    'Avoid literal spacing values; use design-system spacing tokens.',
    correctionMessage: 'Replace the numeric literal with a HiveSpacing token.',
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
      ..addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final NoLiteralSpacing rule;

  static const _edgeInsetsTypes = {'EdgeInsets', 'EdgeInsetsDirectional'};

  static const _gapTypes = {'Gap', 'SliverGap', 'MaxGap'};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = constructedTypeName(node);
    final element = node.constructorName.type.element;

    if (_edgeInsetsTypes.contains(typeName)) {
      if (element == null || isFlutterElement(element)) {
        _reportNumericArguments(node.argumentList);
      }
      return;
    }

    if (typeName == 'SizedBox') {
      if (element == null || isFlutterElement(element)) {
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedArgument &&
              (arg.name.lexeme == 'width' || arg.name.lexeme == 'height') &&
              isNumericLiteral(arg.argumentExpression)) {
            rule.reportAtNode(arg.argumentExpression);
          }
        }
      }
      return;
    }

    if (_gapTypes.contains(typeName)) {
      _reportNumericArguments(node.argumentList);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is! Identifier || !_edgeInsetsTypes.contains(target.name)) {
      return;
    }

    final element = target.element;
    if (element != null && !isFlutterElement(element)) return;

    _reportNumericArguments(node.argumentList);
  }

  void _reportNumericArguments(ArgumentList argumentList) {
    for (final arg in argumentList.arguments) {
      final expr = arg.argumentExpression;
      if (isNumericLiteral(expr)) {
        rule.reportAtNode(expr);
      }
    }
  }
}
