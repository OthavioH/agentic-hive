import 'wave_plan.dart';

/// Builds the fan-out items for [tickets] of [spec], whose PRs target
/// [specBranch].
///
/// [labelOverrides] maps a label to node overrides
/// (`{"<child node id>": {"model": ..., "effort": ...}}`); a ticket with
/// several mapped labels merges them in label order, later labels winning per
/// node.
List<Map<String, Object?>> ticketItems({
  required int spec,
  required String specBranch,
  required List<Ticket> tickets,
  Map<String, Object?> labelOverrides = const {},
}) => [
  for (final t in tickets)
    <String, Object?>{
      'name': 'issue-${t.number}',
      'issue': t.number,
      'input':
          'Implement issue #${t.number} ("${t.title}") of spec #$spec.\n'
          'Spec branch: $specBranch. Open the ticket PR against this base '
          'branch, and put "Closes #${t.number}" in its body.\n'
          'Read the issue with: gh issue view ${t.number} --json '
          'title,body,comments',
      'overrides': _overridesFor(t.labels, labelOverrides),
    },
];

Map<String, Object?> _overridesFor(
  List<String> labels,
  Map<String, Object?> labelOverrides,
) {
  final merged = <String, Map<String, Object?>>{};
  for (final label in labels) {
    final byNode = labelOverrides[label];
    if (byNode is! Map<String, Object?>) continue;
    for (final MapEntry(:key, :value) in byNode.entries) {
      if (value is! Map<String, Object?>) continue;
      (merged[key] ??= {}).addAll(value);
    }
  }
  return merged;
}
