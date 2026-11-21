import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('ApiError', () {
    test('round-trips through JSON with a request id', () {
      const error = ApiError(
        code: ApiErrorCode.notFound,
        message: 'No route.',
        requestId: 'req-1',
      );

      final decoded = ApiError.fromJson(_overTheWire(error.toJson()));

      expect(decoded.code, ApiErrorCode.notFound);
      expect(decoded.message, 'No route.');
      expect(decoded.requestId, 'req-1');
    });

    test('nests its fields under "error"', () {
      const error = ApiError(
        code: ApiErrorCode.internalError,
        message: 'Boom.',
        requestId: 'req-2',
      );

      expect(error.toJson(), {
        'error': {
          'code': 'internal_error',
          'message': 'Boom.',
          'requestId': 'req-2',
        },
      });
    });

    test('omits requestId and details from JSON when they are null', () {
      const error = ApiError(
        code: ApiErrorCode.originNotAllowed,
        message: 'Origin rejected.',
      );

      final body = error.toJson()['error']! as Map<String, Object?>;

      expect(body.containsKey('requestId'), isFalse);
      expect(body.containsKey('details'), isFalse);
      expect(ApiError.fromJson(_overTheWire(error.toJson())).requestId, isNull);
      expect(ApiError.fromJson(_overTheWire(error.toJson())).details, isNull);
    });

    test('round-trips details map through JSON when provided', () {
      const error = ApiError(
        code: ApiErrorCode.badRequest,
        message: 'Validation failed.',
        requestId: 'req-3',
        details: {
          'agentsDir': 'Directory does not exist.',
          'harnessOverrides.codex': 'File is not executable.',
        },
      );

      final decoded = ApiError.fromJson(_overTheWire(error.toJson()));
      expect(decoded, error);
    });

    test('throws a FormatException naming "error" when it is missing', () {
      expect(
        () => ApiError.fromJson({'code': 'x'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"error"'),
          ),
        ),
      );
    });

    test('throws a FormatException naming a missing nested field', () {
      expect(
        () => ApiError.fromJson({
          'error': {'code': 'x'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"message"'),
          ),
        ),
      );
    });
  });
}
