import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:test/test.dart';

void main() {
  const redacted = Redactor.placeholder;

  group('Redactor.isSensitiveKey', () {
    for (final key in [
      'token',
      'accessToken',
      'client_secret',
      'password',
      'passwd',
      'Authorization',
      'apiKey',
      'api_key',
      'X-API-KEY',
      'cookie',
      'Set-Cookie',
      'credentials',
    ]) {
      test('treats "$key" as sensitive', () {
        expect(Redactor().isSensitiveKey(key), isTrue);
      });
    }

    for (final key in ['status', 'runId', 'durationMs', 'path', 'keyword']) {
      test('does not treat "$key" as sensitive', () {
        expect(Redactor().isSensitiveKey(key), isFalse);
      });
    }
  });

  group('Redactor.redactText', () {
    test('hides Bearer credentials and keeps the scheme', () {
      expect(
        Redactor().redactText('Authorization: Bearer abc.def-123 sent'),
        'Authorization: Bearer $redacted sent',
      );
    });

    test('hides Bearer credentials regardless of case', () {
      expect(Redactor().redactText('bearer xyz'), 'bearer $redacted');
    });

    test('hides every occurrence of a registered secret', () {
      final redactor = Redactor()..addSecret('s3cr3t');

      expect(
        redactor.redactText('a s3cr3t b s3cr3t'),
        'a $redacted b $redacted',
      );
    });

    test('hides secrets given to the constructor', () {
      expect(
        Redactor(secrets: ['k1', 'k2']).redactText('k1 and k2'),
        '$redacted and $redacted',
      );
    });

    test('ignores an empty secret', () {
      final redactor = Redactor()..addSecret('');

      expect(redactor.redactText('plain text'), 'plain text');
    });

    test('leaves text without secrets unchanged', () {
      expect(Redactor().redactText('GET /health 200'), 'GET /health 200');
    });
  });

  group('Redactor.redactFields', () {
    test('replaces values of sensitive keys, whatever their type', () {
      expect(
        Redactor().redactFields({
          'token': 'abc',
          'password': 42,
          'apiKey': ['a', 'b'],
          'cookie': {'session': 'x'},
          'status': 200,
        }),
        {
          'token': redacted,
          'password': redacted,
          'apiKey': redacted,
          'cookie': redacted,
          'status': 200,
        },
      );
    });

    test('keeps null, numbers and booleans', () {
      expect(Redactor().redactFields({'a': null, 'b': 1.5, 'c': true}), {
        'a': null,
        'b': 1.5,
        'c': true,
      });
    });

    test('redacts Bearer values and secrets inside string fields', () {
      final redactor = Redactor(secrets: ['hunter2']);

      expect(
        redactor.redactFields({
          'header': 'Bearer abc',
          'note': 'pw is hunter2',
        }),
        {'header': 'Bearer $redacted', 'note': 'pw is $redacted'},
      );
    });

    test('recurses into nested maps', () {
      expect(
        Redactor().redactFields({
          'request': {
            'path': '/x',
            'headers': {'authorization': 'Bearer abc', 'accept': 'json'},
          },
        }),
        {
          'request': {
            'path': '/x',
            'headers': {'authorization': redacted, 'accept': 'json'},
          },
        },
      );
    });

    test('recurses into lists, including maps inside lists', () {
      final redactor = Redactor(secrets: ['zzz']);

      expect(
        redactor.redactFields({
          'items': [
            'has zzz',
            {'secret': 'x', 'id': 1},
            ['Bearer q'],
          ],
        }),
        {
          'items': [
            'has $redacted',
            {'secret': redacted, 'id': 1},
            ['Bearer $redacted'],
          ],
        },
      );
    });

    test('converts other objects to redacted text', () {
      final redactor = Redactor(secrets: ['zzz']);

      expect(redactor.redactFields({'uri': Uri.parse('http://h/zzz')}), {
        'uri': 'http://h/$redacted',
      });
    });
  });
}
