import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

/// Returns `true` when [expression] is a numeric literal (including unary
/// `+` or `-` applied to a numeric literal).
bool isNumericLiteral(Expression expression) {
  final unwrapped = expression is ParenthesizedExpression
      ? expression.expression
      : expression;
  if (unwrapped is IntegerLiteral || unwrapped is DoubleLiteral) {
    return true;
  }
  if (unwrapped is PrefixExpression &&
      (unwrapped.operator.type == TokenType.MINUS ||
          unwrapped.operator.type == TokenType.PLUS)) {
    return isNumericLiteral(unwrapped.operand);
  }
  return false;
}

/// Returns the [Uri] of the library declaring [element], if available.
Uri? declaringLibraryUri(Element? element) => element?.library?.uri;

/// Returns `true` if [element] is declared in `package:flutter/...`.
bool isFlutterElement(Element? element) {
  final uri = declaringLibraryUri(element);
  return uri != null &&
      uri.isScheme('package') &&
      uri.pathSegments.firstOrNull == 'flutter';
}

/// Returns `true` if [element] is declared in `dart:ui`.
bool isDartUiElement(Element? element) {
  final uri = declaringLibraryUri(element);
  return uri != null && uri.isScheme('dart') && uri.path == 'ui';
}

/// Returns the simple name of the type in an [InstanceCreationExpression].
String constructedTypeName(InstanceCreationExpression node) =>
    node.constructorName.type.name.lexeme;
