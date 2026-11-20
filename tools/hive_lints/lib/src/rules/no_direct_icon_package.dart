import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:hive_lints/src/ast_helpers.dart';

/// Flags direct imports of `package:hugeicons/...` and direct uses of
/// `Icons.*` / `CupertinoIcons.*` outside the design system.
class NoDirectIconPackage extends AnalysisRule {
  /// Creates a [NoDirectIconPackage] lint rule.
  new()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid importing hugeicons or using Icons.* directly; use '
            'HiveIcons from the design system instead.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'no_direct_icon_package',
    'Avoid direct icon packages or Icons.*; use HiveIcons instead.',
    correctionMessage: 'Use HiveIcons from package:design_system.',
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
      ..addImportDirective(this, visitor)
      ..addPrefixedIdentifier(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final NoDirectIconPackage rule;

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null &&
        (uri == 'package:hugeicons' || uri.startsWith('package:hugeicons/'))) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix;
    if (prefix.name != 'Icons' && prefix.name != 'CupertinoIcons') return;

    final element = prefix.element;
    if (element == null || isFlutterElement(element)) {
      rule.reportAtNode(node);
    }
  }
}
