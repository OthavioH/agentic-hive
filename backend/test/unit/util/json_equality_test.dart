import 'package:agentic_hive_backend/src/util/json_equality.dart';
import 'package:test/test.dart';

void main() {
  group('jsonEquals', () {
    test('maps with different key order are equal', () {
      expect(jsonEquals({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isTrue);
    });

    test('lists are order-sensitive', () {
      expect(jsonEquals([1, 2], [1, 2]), isTrue);
      expect(jsonEquals([1, 2], [2, 1]), isFalse);
    });

    test('1 and 1.0 are equal', () {
      expect(jsonEquals(1, 1.0), isTrue);
    });

    test('nested difference is unequal', () {
      expect(
        jsonEquals(
          {
            'items': [
              {'id': 1, 'ok': true},
            ],
          },
          {
            'items': [
              {'id': 1, 'ok': false},
            ],
          },
        ),
        isFalse,
      );
    });

    test('null value vs missing key are unequal', () {
      expect(jsonEquals({'a': null}, <String, Object?>{}), isFalse);
    });
  });
}
