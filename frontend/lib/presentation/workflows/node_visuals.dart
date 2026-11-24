import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

Color _warningAccent(HiveColors colors) => colors.warning;

/// Registers visuals for all 11 canonical [NodeDescriptors] in [registry].
void registerCanonicalNodeVisuals(NodeVisualRegistry registry) {
  const entries = <String, NodeVisual>{
    NodeTypeId.claudeCode: NodeVisual(
      icon: HiveIcons.harnessClaudeCode,
      labelKey: 'nodeTypeClaudeCode',
    ),
    NodeTypeId.codex: NodeVisual(
      icon: HiveIcons.harnessCodex,
      labelKey: 'nodeTypeCodex',
    ),
    NodeTypeId.geminiCli: NodeVisual(
      icon: HiveIcons.harnessGeminiCli,
      labelKey: 'nodeTypeGeminiCli',
    ),
    NodeTypeId.antigravity: NodeVisual(
      icon: HiveIcons.harnessAntigravity,
      labelKey: 'nodeTypeAntigravity',
    ),
    NodeTypeId.terminal: NodeVisual(
      icon: HiveIcons.harnessTerminal,
      labelKey: 'nodeTypeTerminalHarness',
    ),
    NodeTypeId.command: NodeVisual(
      icon: HiveIcons.terminal,
      labelKey: 'nodeTypeCommand',
    ),
    NodeTypeId.testsValidator: NodeVisual(
      icon: HiveIcons.validatorTests,
      labelKey: 'nodeTypeTestsValidator',
    ),
    NodeTypeId.checklistValidator: NodeVisual(
      icon: HiveIcons.validatorChecklist,
      labelKey: 'nodeTypeChecklistValidator',
    ),
    NodeTypeId.reviewValidator: NodeVisual(
      icon: HiveIcons.validatorReview,
      labelKey: 'nodeTypeReviewValidator',
    ),
    NodeTypeId.humanApproval: NodeVisual(
      icon: HiveIcons.person,
      labelKey: 'nodeTypeHumanApproval',
      accent: _warningAccent,
    ),
    NodeTypeId.fanOut: NodeVisual(
      icon: HiveIcons.branch,
      labelKey: 'nodeTypeFanOut',
    ),
  };

  for (final entry in entries.entries) {
    registry.register(entry.key, entry.value);
  }
}

/// Creates a [NodeVisualRegistry] pre-populated with all canonical node types.
NodeVisualRegistry createNodeVisualRegistry() {
  final registry = NodeVisualRegistry();
  registerCanonicalNodeVisuals(registry);
  return registry;
}

final Map<String, String Function(AppLocalizations)> _labelKeyResolvers =
    <String, String Function(AppLocalizations)>{
      'nodeTypeClaudeCode': (l10n) => l10n.nodeTypeClaudeCode,
      'nodeTypeCodex': (l10n) => l10n.nodeTypeCodex,
      'nodeTypeGeminiCli': (l10n) => l10n.nodeTypeGeminiCli,
      'nodeTypeAntigravity': (l10n) => l10n.nodeTypeAntigravity,
      'nodeTypeTerminalHarness': (l10n) => l10n.nodeTypeTerminalHarness,
      'nodeTypeCommand': (l10n) => l10n.nodeTypeCommand,
      'nodeTypeTestsValidator': (l10n) => l10n.nodeTypeTestsValidator,
      'nodeTypeChecklistValidator': (l10n) => l10n.nodeTypeChecklistValidator,
      'nodeTypeReviewValidator': (l10n) => l10n.nodeTypeReviewValidator,
      'nodeTypeHumanApproval': (l10n) => l10n.nodeTypeHumanApproval,
      'nodeTypeFanOut': (l10n) => l10n.nodeTypeFanOut,
      'nodeTypeUnknown': (l10n) => l10n.nodeTypeUnknown,
    };

/// Resolves a [NodeVisual.labelKey] into a localized display string.
String resolveNodeVisualLabel(AppLocalizations l10n, String labelKey) {
  final resolver = _labelKeyResolvers[labelKey];
  return resolver != null ? resolver(l10n) : l10n.nodeTypeUnknown;
}

/// Resolves the localized display name for [typeId] via [NodeVisualScope].
String resolveNodeTypeLabel(
  BuildContext context,
  AppLocalizations l10n,
  String typeId,
) {
  final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();
  final visual = scope?.registry.resolve(typeId) ?? NodeVisual.fallback;
  return resolveNodeVisualLabel(l10n, visual.labelKey);
}

/// Resolves the localized display name for a [NodeCategory].
String resolveNodeCategoryLabel(AppLocalizations l10n, NodeCategory category) {
  return switch (category) {
    NodeCategory.harnesses => l10n.nodeCategoryHarnesses,
    NodeCategory.execution => l10n.nodeCategoryExecution,
    NodeCategory.validators => l10n.nodeCategoryValidators,
    NodeCategory.human => l10n.nodeCategoryHuman,
  };
}
