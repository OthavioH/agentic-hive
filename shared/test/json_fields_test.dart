import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:test/test.dart';

Matcher _formatErrorNaming(String field) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  contains('"$field"'),
);

void main() {
  group('readField', () {
    test('returns the value when it has the requested type', () {
      expect(readField<String>({'name': 'hive'}, 'name'), 'hive');
      expect(readField<int>({'count': 3}, 'count'), 3);
    });

    test('throws a FormatException naming a missing required field', () {
      expect(
        () => readField<String>({}, 'name'),
        throwsA(_formatErrorNaming('name')),
      );
    });

    test('throws a FormatException naming a field of the wrong type', () {
      expect(
        () => readField<int>({'count': '3'}, 'count'),
        throwsA(_formatErrorNaming('count')),
      );
    });

    test('accepts a missing key or null for a nullable type', () {
      expect(readField<String?>({}, 'name'), isNull);
      expect(readField<String?>({'name': null}, 'name'), isNull);
    });

    test('rejects a wrong type for a nullable type', () {
      expect(
        () => readField<String?>({'name': 1}, 'name'),
        throwsA(_formatErrorNaming('name')),
      );
    });
  });

  group('readObject', () {
    test('returns a nested JSON object', () {
      expect(
        readObject({
          'inner': <String, Object?>{'a': 1},
        }, 'inner'),
        {'a': 1},
      );
    });

    test('accepts a map that is not typed Map<String, Object?>', () {
      final inner = <Object, Object>{'a': 1};
      final result = readObject({'inner': inner}, 'inner');
      expect(result, isA<Map<String, Object?>>());
      expect(result['a'], 1);
    });

    test('throws a FormatException naming a missing object', () {
      expect(
        () => readObject({}, 'inner'),
        throwsA(_formatErrorNaming('inner')),
      );
    });

    test('throws a FormatException naming a field that is not an object', () {
      expect(
        () => readObject({
          'inner': const [1],
        }, 'inner'),
        throwsA(_formatErrorNaming('inner')),
      );
    });
  });
}
