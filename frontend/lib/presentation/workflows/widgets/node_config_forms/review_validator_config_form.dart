import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/agent_library_select_field.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/node_config_form_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `validator.review`
/// ([ReviewValidatorNodeConfig]).
class ReviewValidatorConfigForm extends StatefulWidget {
  /// Creates a [ReviewValidatorConfigForm].
  const new({required this.node, required this.onConfigChanged, super.key});

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  @override
  State<ReviewValidatorConfigForm> createState() =>
      _ReviewValidatorConfigFormState();
}

class _ReviewValidatorConfigFormState extends State<ReviewValidatorConfigForm> {
  final TextEditingController _criteriaController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  String? _agentId;
  String _harnessType = NodeTypeId.claudeCode;
  bool _hasTimeoutError = false;

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(ReviewValidatorConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _criteriaController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    _hasTimeoutError = false;
    final config = _parseConfig(widget.node.config);
    _harnessType = headlessHarnessTypeIds.contains(config.harnessType)
        ? config.harnessType
        : NodeTypeId.claudeCode;
    _agentId = _nullIfEmpty(config.agentId ?? '');
    _criteriaController.text = config.reviewCriteria ?? '';
    _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
  }

  ReviewValidatorNodeConfig _parseConfig(JsonMap raw) {
    try {
      return ReviewValidatorNodeConfig.fromJson(raw);
    } on FormatException {
      return const ReviewValidatorNodeConfig(
        harnessType: NodeTypeId.claudeCode,
        reviewCriteria: '',
      );
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _emit() {
    final timeout = parsePositiveTimeout(_timeoutController.text);
    if (_hasTimeoutError != !timeout.isValid) {
      setState(() => _hasTimeoutError = !timeout.isValid);
    }
    if (!timeout.isValid) return;

    widget.onConfigChanged(
      ReviewValidatorNodeConfig(
        harnessType: _harnessType,
        agentId: _agentId,
        reviewCriteria: _nullIfEmpty(_criteriaController.text),
        timeoutSeconds: timeout.value,
      ).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();

    final harnessOptions = <HiveSelectOption<String>>[
      for (final typeId in headlessHarnessTypeIds)
        HiveSelectOption<String>(
          value: typeId,
          label: resolveNodeVisualLabel(
            l10n,
            (scope?.registry.resolve(typeId) ?? NodeVisual.fallback).labelKey,
          ),
          icon: scope?.registry.resolve(typeId).icon,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveSelect<String>(
          key: const Key('config_review_harness_type'),
          label: l10n.nodeConfigReviewHarnessLabel,
          value: _harnessType,
          options: harnessOptions,
          onChanged: (value) {
            setState(() => _harnessType = value);
            _emit();
          },
        ),
        SizedBox(height: spacing.space2),
        AgentLibrarySelectField(
          selectKey: const Key('config_review_agent_id'),
          agentId: _agentId,
          onChanged: (value) {
            setState(() => _agentId = value);
            _emit();
          },
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_review_criteria'),
          label: l10n.nodeConfigReviewCriteriaLabel,
          hint: l10n.nodeConfigReviewCriteriaHint,
          controller: _criteriaController,
          multiline: true,
          maxLines: 4,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_review_timeout_seconds'),
          label: l10n.nodeConfigTimeoutSecondsLabel,
          hint: l10n.nodeConfigTimeoutSecondsHint,
          errorText: _hasTimeoutError
              ? l10n.nodeConfigTimeoutSecondsError
              : null,
          controller: _timeoutController,
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
