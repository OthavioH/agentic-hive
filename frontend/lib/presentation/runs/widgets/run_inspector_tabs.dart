import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Views available in the right-hand inspector of the Live Run Monitor.
enum RunInspectorTab {
  /// Streaming and historical `stdout`/`stderr` output of a node.
  output,

  /// Chronological event log of the run.
  events,

  /// Saved checkpoints of the run.
  checkpoints,

  /// Workspace snapshots of the run.
  snapshots,
}

/// Segmented toggle between Output, Events, Checkpoints, and Snapshots tabs.
class RunInspectorTabs extends StatelessWidget {
  /// Creates the toggle.
  const new({required this.selected, required this.onChanged, super.key});

  /// Currently shown view.
  final RunInspectorTab selected;

  /// Called when another view is picked.
  final ValueChanged<RunInspectorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HiveSegmentedControl<RunInspectorTab>(
      semanticLabel: l10n.runDetailTabsLabel,
      selected: selected,
      onChanged: onChanged,
      segments: <HiveSegment<RunInspectorTab>>[
        HiveSegment<RunInspectorTab>(
          value: RunInspectorTab.output,
          label: l10n.runDetailTabOutput,
        ),
        HiveSegment<RunInspectorTab>(
          value: RunInspectorTab.events,
          label: l10n.runDetailTabEvents,
        ),
        HiveSegment<RunInspectorTab>(
          value: RunInspectorTab.checkpoints,
          label: l10n.runDetailTabCheckpoints,
        ),
        HiveSegment<RunInspectorTab>(
          value: RunInspectorTab.snapshots,
          label: l10n.runDetailTabSnapshots,
        ),
      ],
    );
  }
}
