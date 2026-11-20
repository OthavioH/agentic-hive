import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Success exposes value, isSuccess, and fold branch', () {
      const Result<int> result = Success<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
      expect(
        result.fold(
          onSuccess: (value) => 'ok:$value',
          onFailure: (failure) => 'err:${failure.message}',
        ),
        'ok:42',
      );
    });

    test('FailureResult exposes failure, isFailure, and fold branch', () {
      const failure = NotFoundFailure('Missing workflow');
      const Result<int> result = FailureResult<int>(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
      expect(
        result.fold(
          onSuccess: (value) => 'ok:$value',
          onFailure: (f) => 'err:${f.message}',
        ),
        'err:Missing workflow',
      );
    });

    test('map transforms Success and preserves FailureResult', () {
      const Result<int> ok = Success<int>(10);
      const Result<int> err = FailureResult<int>(
        ValidationFailure('Bad input'),
      );

      expect(ok.map((v) => v * 2).valueOrNull, 20);
      expect(err.map((v) => v * 2).failureOrNull, isA<ValidationFailure>());
    });

    test('flatMap chains Success and short-circuits FailureResult', () {
      Result<int> parsePositive(String raw) {
        final parsed = int.tryParse(raw);
        if (parsed == null || parsed <= 0) {
          return const FailureResult<int>(ValidationFailure('Must be > 0'));
        }
        return Success<int>(parsed);
      }

      const Result<String> ok = Success<String>('5');
      const Result<String> bad = Success<String>('-1');
      const Result<String> alreadyFailed = FailureResult<String>(
        NotFoundFailure('No input'),
      );

      expect(ok.flatMap(parsePositive).valueOrNull, 5);
      expect(
        bad.flatMap(parsePositive).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        alreadyFailed.flatMap(parsePositive).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });
}
