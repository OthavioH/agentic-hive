import 'package:test/test.dart';

import '../../../tool/src/bundle/output_tail.dart';

void main() {
  group('OutputTail', () {
    test('keeps only the last maxLines lines', () {
      final tail = OutputTail(maxLines: 2)..add('a\nb\nc\n');

      expect(tail.text, 'b\nc');
    });

    test('joins chunks split mid-line', () {
      final tail = OutputTail()
        ..add('ab')
        ..add('c\nd');

      expect(tail.text, 'abc\nd');
    });

    test('empty returns empty string', () {
      final tail = OutputTail();

      expect(tail.text, '');
    });
  });
}
