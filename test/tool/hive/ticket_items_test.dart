import 'package:test/test.dart';

import '../../../tool/src/hive/ticket_items.dart';
import '../../../tool/src/hive/wave_plan.dart';

void main() {
  test('builds one named item per ticket with its input', () {
    final items = ticketItems(
      spec: 100,
      specBranch: 'spec/100',
      tickets: const [Ticket(number: 116, title: 'Preparers', isOpen: true)],
    );
    expect(items.single['name'], 'issue-116');
    expect(items.single['input'], contains('Spec branch: spec/100'));
    expect(items.single['input'], contains('Closes #116'));
    expect(items.single['overrides'], isEmpty);
  });

  test('merges label overrides per node, later labels winning', () {
    final items = ticketItems(
      spec: 1,
      specBranch: 'spec/1',
      tickets: const [
        Ticket(number: 2, title: 't', isOpen: true, labels: ['a', 'b', 'c']),
      ],
      labelOverrides: {
        'a': {
          'implement': {'model': 'm1', 'effort': 'low'},
        },
        'b': {
          'implement': {'model': 'm2'},
        },
      },
    );
    expect(items.single['overrides'], {
      'implement': {'model': 'm2', 'effort': 'low'},
    });
  });
}
