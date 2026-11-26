import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Edits the ordered fallback list on a headless harness node.
class FallbackListEditor extends ConsumerStatefulWidget {
  /// Creates a [FallbackListEditor].
  const new({
    required this.nodeType,
    required this.entries,
    required this.onChanged,
    super.key,
  });

  /// The node's own `WorkflowNode.type`, used to pick the default harness for
  /// newly added rows.
  final String nodeType;

  /// Initial fallback entries from the node configuration.
  final List<FallbackEntry> entries;

  /// Called whenever any row is added, edited, reordered, or removed.
  final ValueChanged<List<FallbackEntry>> onChanged;

  @override
  ConsumerState<FallbackListEditor> createState() => _FallbackListEditorState();
}

class _FallbackRowState {
  new({
    required this.id,
    required this.harness,
    required String? model,
    required this.effort,
  }) : model = TextEditingController(text: model ?? '');

  final int id;
  String harness;
  final TextEditingController model;
  String? effort;

  void dispose() => model.dispose();
}

class _FallbackListEditorState extends ConsumerState<FallbackListEditor> {
  final List<_FallbackRowState> _rows = <_FallbackRowState>[];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _syncRows();
  }

  @override
  void didUpdateWidget(FallbackListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeType != widget.nodeType ||
        !listEquals(_currentEntries(), widget.entries)) {
      _clearRows();
      _syncRows();
    }
  }

  @override
  void dispose() {
    _clearRows();
    super.dispose();
  }

  void _clearRows() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
  }

  void _syncRows() {
    for (final entry in widget.entries) {
      _rows.add(
        _FallbackRowState(
          id: _nextId++,
          harness: entry.harness,
          model: entry.model,
          effort: _nullIfEmpty(entry.effort ?? ''),
        ),
      );
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _defaultHarness() {
    for (final typeId in headlessHarnessTypeIds) {
      if (typeId != widget.nodeType) return typeId;
    }
    return headlessHarnessTypeIds.first;
  }

  List<FallbackEntry> _currentEntries() => <FallbackEntry>[
    for (final row in _rows)
      FallbackEntry(
        harness: row.harness,
        model: _nullIfEmpty(row.model.text),
        effort: row.effort,
      ),
  ];

  void _emit() {
    widget.onChanged(_currentEntries());
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _FallbackRowState(
          id: _nextId++,
          harness: _defaultHarness(),
          model: null,
          effort: null,
        ),
      );
    });
    _emit();
  }

  void _moveRow(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
    _emit();
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;

    return HiveCollapsibleSection(
      title: l10n.nodeConfigFallbackTitle,
      initiallyExpanded: true,
      child: _rows.isEmpty
          ? HiveEmptyState(
              icon: HiveIcons.harnesses,
              title: l10n.nodeConfigFallbackTitle,
              message: l10n.nodeConfigFallbackEmpty,
              action: HiveButton(
                key: const Key('config_fallback_add'),
                label: l10n.nodeConfigFallbackAdd,
                icon: HiveIcons.add,
                variant: HiveButtonVariant.secondary,
                onPressed: _addRow,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < _rows.length; i++) ...<Widget>[
                  _FallbackRowCard(
                    key: ValueKey<int>(_rows[i].id),
                    index: i,
                    row: _rows[i],
                    onHarnessChanged: (harness) {
                      setState(() => _rows[i].harness = harness);
                      _emit();
                    },
                    onModelChanged: (_) {
                      setState(() {});
                      _emit();
                    },
                    onEffortChanged: (effort) {
                      setState(() => _rows[i].effort = effort);
                      _emit();
                    },
                    onMoveUp: i == 0 ? null : () => _moveRow(i, -1),
                    onMoveDown: i == _rows.length - 1
                        ? null
                        : () => _moveRow(i, 1),
                    onRemove: () => _removeRow(i),
                  ),
                  SizedBox(height: spacing.space2),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: HiveButton(
                    key: const Key('config_fallback_add'),
                    label: l10n.nodeConfigFallbackAdd,
                    icon: HiveIcons.add,
                    variant: HiveButtonVariant.secondary,
                    onPressed: _addRow,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FallbackRowCard extends ConsumerWidget {
  const new({
    required this.index,
    required this.row,
    required this.onHarnessChanged,
    required this.onModelChanged,
    required this.onEffortChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _FallbackRowState row;
  final ValueChanged<String> onHarnessChanged;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String?> onEffortChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final harnessLabel = resolveNodeTypeLabel(context, l10n, row.harness);
    final effortSupported = NodeTypeChange.supportedFields(row.harness)
        .contains('effort');
    final showEffort = effortSupported || row.effort != null;
    final modelStartsWithDash = row.model.text.trim().startsWith('-');
    final statuses = ref.watch(harnessStatusByTypeIdProvider);
    final status = statuses?[row.harness];

    String? statusBadgeLabel;
    if (status == HarnessStatus.notInstalled) {
      statusBadgeLabel = l10n.nodeConfigFallbackNotInstalled(harnessLabel);
    } else if (status == HarnessStatus.authError) {
      statusBadgeLabel = l10n.nodeConfigFallbackNotSignedIn(harnessLabel);
    }

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HiveSelect<String>(
            key: Key('config_fallback_${row.id}_harness'),
            label: l10n.nodeConfigFallbackHarnessLabel,
            value: row.harness,
            options: <HiveSelectOption<String>>[
              for (final typeId in headlessHarnessTypeIds)
                HiveSelectOption<String>(
                  value: typeId,
                  label: resolveNodeTypeLabel(context, l10n, typeId),
                ),
            ],
            onChanged: onHarnessChanged,
          ),
          SizedBox(height: spacing.space1),
          HiveTextField(
            key: Key('config_fallback_${row.id}_model'),
            label: l10n.nodeConfigFallbackModelLabel,
            hint: l10n.nodeConfigHarnessDefaultHint,
            errorText: modelStartsWithDash
                ? l10n.nodeConfigFallbackModelDashError
                : null,
            controller: row.model,
            onChanged: onModelChanged,
          ),
          if (showEffort) ...<Widget>[
            SizedBox(height: spacing.space1),
            _buildEffortSelect(l10n, harnessLabel, effortSupported),
          ],
          SizedBox(height: spacing.space1),
          Wrap(
            spacing: spacing.space1,
            runSpacing: spacing.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              HiveIconButton(
                key: Key('config_fallback_${row.id}_up'),
                icon: HiveIcons.moveUp,
                semanticLabel: l10n.nodeConfigFallbackMoveUp(index + 1),
                onPressed: onMoveUp,
              ),
              HiveIconButton(
                key: Key('config_fallback_${row.id}_down'),
                icon: HiveIcons.moveDown,
                semanticLabel: l10n.nodeConfigFallbackMoveDown(index + 1),
                onPressed: onMoveDown,
              ),
              HiveIconButton(
                key: Key('config_fallback_${row.id}_remove'),
                icon: HiveIcons.delete,
                semanticLabel: l10n.nodeConfigFallbackRemove(index + 1),
                onPressed: onRemove,
              ),
              if (statusBadgeLabel != null)
                HiveBadge(
                  key: Key('config_fallback_${row.id}_status'),
                  tone: HiveBadgeTone.warning,
                  label: statusBadgeLabel,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffortSelect(
    AppLocalizations l10n,
    String harnessLabel,
    bool effortSupported,
  ) {
    final current = row.effort;
    final known = HarnessEffort.tryParse(current) != null;
    String? error;
    if (!effortSupported) {
      error = l10n.nodeConfigEffortUnsupportedError(harnessLabel);
    } else if (current != null && !known) {
      error = l10n.nodeConfigEffortInvalidError(current);
    }
    return HiveSelect<String>(
      key: Key('config_fallback_${row.id}_effort'),
      label: l10n.nodeConfigFallbackEffortLabel,
      hint: l10n.nodeConfigHarnessDefaultHint,
      errorText: error,
      value: current,
      options: <HiveSelectOption<String>>[
        HiveSelectOption<String>(
          value: '',
          label: l10n.nodeConfigHarnessDefaultHint,
        ),
        if (current != null && !known)
          HiveSelectOption<String>(value: current, label: current),
        for (final level in HarnessEffort.values)
          HiveSelectOption<String>(
            value: level.name,
            label: _effortLabel(l10n, level),
          ),
      ],
      onChanged: (picked) => onEffortChanged(picked.isEmpty ? null : picked),
    );
  }

  String _effortLabel(AppLocalizations l10n, HarnessEffort level) =>
      switch (level) {
        HarnessEffort.low => l10n.nodeConfigEffortLow,
        HarnessEffort.medium => l10n.nodeConfigEffortMedium,
        HarnessEffort.high => l10n.nodeConfigEffortHigh,
        HarnessEffort.max => l10n.nodeConfigEffortMax,
      };
}
