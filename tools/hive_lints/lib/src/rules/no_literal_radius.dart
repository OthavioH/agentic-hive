import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags numeric literal radius values in `BorderRadius`,
/// `BorderRadiusDirectional`, and `Radius` constructors.
class NoLiteralRadius extends AnalysisRule {
  /// Creates a [NoLiteralRadius] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid numeric literal values in BorderRadius and Radius; use '
            'design-system radius tokens instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_literal_radius',
    'Avoid literal radius values; use design-system radius tokens.',
    correctionMessage: 'Replace the numeric literal with a HiveRadius token.',
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

  final NoLiteralRadius rule;

  static const _radiusTypes = {
    'BorderRadius',
    'BorderRadiusDirectional',
    'Radius',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = constructedTypeName(node);
    if (!_radiusTypes.contains(typeName)) return;

    final element = node.constructorName.type.element;
    if (element != null &&
        !isFlutterElement(element) &&
        !isDartUiElement(element)) {
      return;
    }

    _reportNumericArguments(node.argumentList);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is! Identifier || !_radiusTypes.contains(target.name)) return;

    final element = target.element;
    if (element != null &&
        !isFlutterElement(element) &&
        !isDartUiElement(element)) {
      return;
    }

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
