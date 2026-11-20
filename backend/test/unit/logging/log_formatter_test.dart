import 'dart:convert';

import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/logging/log_formatter.dart';
import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

const _secret = 'sk-very-secret-value';

LogRecord _record(
  Level level,
  Object message, {
  Object? error,
  StackTrace? stackTrace,
}) => LogRecord(
  level,
  message.toString(),
  'test.logger',
  error,
  stackTrace,
  null,
  message,
);

void main() {
  late LogFormatter formatter;

  setUp(() {
    formatter = LogFormatter(Redactor(secrets: [_secret]));
  });

  group('LogFormatter.toJson', () {
    test('writes time, level, logger, message and fields', () {
      final json = formatter.toJson(
        _record(
          Level.INFO,
          const LogEvent('http.request', fields: {'status': 200}),
        ),
      );

      expect(json.keys, ['time', 'level', 'logger', 'message', 'fields']);
      expect(json['level'], 'INFO');
      expect(json['logger'], 'test.logger');
      expect(json['message'], 'http.request');
      expect(json['fields'], {'status': 200});
      final time = DateTime.parse(json['time']! as String);
      expect(time.isUtc, isTrue);
      expect(json['time'], endsWith('Z'));
    });

    test('omits fields when the event has none', () {
      final json = formatter.toJson(
        _record(Level.INFO, const LogEvent('app.started')),
      );

      expect(json.containsKey('fields'), isFalse);
    });

    test('uses the plain message for a record that is not a LogEvent', () {
      final json = formatter.toJson(_record(Level.WARNING, 'plain text'));

      expect(json['message'], 'plain text');
      expect(json.containsKey('fields'), isFalse);
    });

    test('toJsonLine is one line of the same JSON', () {
      final record = _record(Level.INFO, const LogEvent('e', fields: {'n': 1}));

      final line = formatter.toJsonLine(record);

      expect(line, isNot(contains('\n')));
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['message'], 'e');
      expect(decoded['fields'], {'n': 1});
    });
  });

  group('userContent', () {
    const event = LogEvent('agent.output', userContent: 'the prompt');

    for (final level in [Level.FINEST, Level.FINER, Level.FINE, Level.CONFIG]) {
      test('is written at $level', () {
        expect(
          formatter.toJson(_record(level, event))['userContent'],
          'the '
          'prompt',
        );
      });
    }

    for (final level in [Level.INFO, Level.WARNING, Level.SEVERE]) {
      test('is not written at $level', () {
        final json = formatter.toJson(_record(level, event));

        expect(json.containsKey('userContent'), isFalse);
        expect(
          formatter.toConsoleLine(_record(level, event)),
          isNot(contains('the prompt')),
        );
      });
    }

    test('is kept whole at exactly the maximum length', () {
      final content = 'a' * LogFormatter.maxUserContentLength;

      final json = formatter.toJson(
        _record(Level.FINE, LogEvent('e', userContent: content)),
      );

      expect(json['userContent'], content);
    });

    test('is truncated to 500 characters plus an ellipsis', () {
      final content = 'b' * 501;

      final json = formatter.toJson(
        _record(Level.FINE, LogEvent('e', userContent: content)),
      );

      expect(LogFormatter.maxUserContentLength, 500);
      expect(json['userContent'], '${'b' * 500}…');
    });

    test('appears in the console line below INFO', () {
      final line = formatter.toConsoleLine(_record(Level.FINE, event));

      expect(line, contains('\n  content: the prompt'));
    });
  });

  group('secrets never appear', () {
    for (final level in [Level.FINEST, Level.FINE, Level.INFO, Level.SEVERE]) {
      test('at $level in JSON or on the console', () {
        final record = _record(
          level,
          const LogEvent(
            'leak $_secret',
            fields: {
              'token': 'tok-123',
              'note': 'key=$_secret',
              'header': 'Bearer bearer-cred',
              'nested': {
                'items': [_secret],
              },
            },
            userContent: 'user pasted $_secret and Bearer bearer-cred',
          ),
          error: StateError('failed with $_secret'),
        );

        final outputs = [
          formatter.toJsonLine(record),
          formatter.toConsoleLine(record),
        ];

        for (final output in outputs) {
          expect(output, isNot(contains(_secret)));
          expect(output, isNot(contains('tok-123')));
          expect(output, isNot(contains('bearer-cred')));
          expect(output, contains(Redactor.placeholder));
        }
      });
    }

    test('in a plain-string message', () {
      final record = _record(Level.INFO, 'sending Bearer abc and $_secret');

      expect(formatter.toJsonLine(record), isNot(contains(_secret)));
      expect(formatter.toConsoleLine(record), isNot(contains('abc')));
    });

    test('in a stack trace', () {
      final record = _record(
        Level.SEVERE,
        const LogEvent('e'),
        error: 'x',
        stackTrace: StackTrace.fromString('#0 main ($_secret)'),
      );

      expect(formatter.toJsonLine(record), isNot(contains(_secret)));
      expect(formatter.toConsoleLine(record), isNot(contains(_secret)));
    });
  });

  group('errors', () {
    test('writes the error and the stack trace to JSON', () {
      final stackTrace = StackTrace.fromString('#0 main (file.dart:1)');

      final json = formatter.toJson(
        _record(
          Level.SEVERE,
          const LogEvent('boom'),
          error: StateError('bad state'),
          stackTrace: stackTrace,
        ),
      );

      expect(json['error'], 'Bad state: bad state');
      expect(json['stackTrace'], '#0 main (file.dart:1)');
    });

    test('omits error and stackTrace when the record has none', () {
      final json = formatter.toJson(_record(Level.SEVERE, const LogEvent('x')));

      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
    });

    test('puts the error and stack trace on their own console lines', () {
      final line = formatter.toConsoleLine(
        _record(
          Level.SEVERE,
          const LogEvent('boom'),
          error: 'it broke',
          stackTrace: StackTrace.fromString('#0 main (file.dart:1)'),
        ),
      );

      expect(line, contains('\n  error: it broke'));
      expect(line, endsWith('\n#0 main (file.dart:1)'));
    });
  });

  group('LogFormatter.toConsoleLine', () {
    test('writes time, padded level, logger, message and fields', () {
      final line = formatter.toConsoleLine(
        _record(
          Level.INFO,
          const LogEvent('http.request', fields: {'status': 200, 'ms': 3}),
        ),
      );

      expect(
        line,
        matches(
          RegExp(
            r'^\d{4}-\d{2}-\d{2}T[\d:.]+Z INFO    test\.logger: '
            r'http\.request status=200 ms=3$',
          ),
        ),
      );
    });
  });
}
