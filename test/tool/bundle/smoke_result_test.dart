import 'package:test/test.dart';

import '../../../tool/src/bundle/smoke_result.dart';

void main() {
  group('SmokeResult', () {
    test('SmokePassed has exitCode 0 and formatted message', () {
      const result = SmokePassed(Duration(milliseconds: 3300));

      expect(result.exitCode, 0);
      expect(result.message, startsWith('PASSED'));
      expect(result.message, contains('MCP initialize'));
      expect(result.message, contains('3.3s'));
    });

    test('every failure has exitCode 1', () {
      final failures = <SmokeFailure>[
        const MissingFilesFailure(['a']),
        const ServerLaunchFailure('/b/server', 'denied'),
        const ServerExitedFailure(1, 'err'),
        const ServerInfoTimeoutFailure(
          '/t/server.json',
          Duration(seconds: 30),
          'x',
        ),
        const InvalidServerInfoFailure('/t/server.json', 'bad'),
        const HealthCheckFailure(500, 'boom'),
        const McpProxyFailure(
          'exited with code 255 before answering',
          'Usage: dartvm',
        ),
        const StopFailure('killed'),
      ];

      for (final failure in failures) {
        expect(failure.exitCode, 1);
      }
    });

    test('MissingFilesFailure formats missing paths on separate lines', () {
      const failure = MissingFilesFailure(['/a', '/b']);

      expect(failure.message, startsWith('FAILED at layout: missing file(s):'));
      expect(failure.message, contains('\n  - /a\n  - /b'));
    });

    test('ServerExitedFailure formats exit code and output', () {
      const failure = ServerExitedFailure(255, 'Null check operator');

      expect(failure.message, contains('FAILED at start'));
      expect(failure.message, contains('code 255 before writing server.json'));
      expect(failure.message, contains('Null check operator'));

      const emptyOutput = ServerExitedFailure(255, '');
      expect(emptyOutput.message, contains('(no output)'));
    });

    test('ServerLaunchFailure includes serverPath and error', () {
      const failure = ServerLaunchFailure(
        '/b/backend/bin/server',
        'Permission denied',
      );

      expect(failure.message, contains('/b/backend/bin/server'));
      expect(failure.message, contains('Permission denied'));
    });

    test('ServerInfoTimeoutFailure includes path and timeout seconds', () {
      const failure = ServerInfoTimeoutFailure(
        '/t/data/server.json',
        Duration(seconds: 30),
        'x',
      );

      expect(failure.message, contains('/t/data/server.json'));
      expect(failure.message, contains('30s'));
    });

    test('InvalidServerInfoFailure formats step, path, and reason', () {
      const failure = InvalidServerInfoFailure('/t/server.json', 'bad json');

      expect(failure.message, contains('FAILED at server.json'));
      expect(failure.message, contains('/t/server.json'));
      expect(failure.message, contains('bad json'));
    });

    test('HealthCheckFailure formats status code or connection failure', () {
      const withStatus = HealthCheckFailure(500, 'boom');
      expect(withStatus.message, contains('GET /health answered 500: boom'));

      const withoutStatus = HealthCheckFailure(null, 'refused');
      expect(withoutStatus.message, contains('GET /health failed: refused'));
    });

    test('StopFailure formats reason', () {
      const failure = StopFailure('killed');

      expect(
        failure.message,
        'FAILED at stop: the server did not stop cleanly: killed',
      );
    });

    test('McpProxyFailure formats step, reason, and output', () {
      const failure = McpProxyFailure(
        'exited with code 255 before answering',
        'Usage: dartvm',
      );

      expect(failure.message, contains('FAILED at mcp'));
      expect(
        failure.message,
        contains('exited with code 255 before answering'),
      );
      expect(failure.message, contains('Usage: dartvm'));

      const emptyOutput = McpProxyFailure('x', '');
      expect(emptyOutput.message, contains('(no output)'));
    });
  });
}
