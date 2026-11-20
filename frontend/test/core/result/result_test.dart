import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success exposes value and transforms with map/flatMap', () {
      const result = Success<int>(21);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 21);
      expect(result.failureOrNull, isNull);

      final doubled = result.map((value) => value * 2);
      expect(doubled.valueOrNull, 42);

      final chained = doubled.flatMap((value) => Success<String>('$value'));
      expect(chained.valueOrNull, '42');

      final folded = chained.fold(
        onSuccess: (value) => 'ok:$value',
        onFailure: (failure) => 'err:${failure.message}',
      );
      expect(folded, 'ok:42');
    });

    test('FailureResult short-circuits map/flatMap and folds failure', () {
      const failure = NetworkFailure('socket missing');
      const result = FailureResult<int>(failure);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));

      final mapped = result.map((value) => value * 2);
      expect(mapped.failureOrNull, same(failure));

      final chained = result.flatMap((value) => Success<String>('$value'));
      expect(chained.failureOrNull, same(failure));

      final folded = result.fold(
        onSuccess: (value) => 'ok:$value',
        onFailure: (f) => 'err:${f.message}',
      );
      expect(folded, 'err:socket missing');
    });
  });
}
