import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('HiveMcpLocator', () {
    test('discovers companion binary on Windows', () {
      final locator = HiveMcpLocator(
        binaryNaming: mcpBinaryNamingFor('windows'),
        resolvedExecutable: r'C:\Program Files\AgenticHive\server.exe',
        fileExists: (path) =>
            path == r'C:\Program Files\AgenticHive\hive-mcp.exe',
        pathContext: p.windows,
      );

      final result = locator.resolve();
      expect(result.isSuccess, isTrue);
      final launch = result.valueOrNull!;
      expect(launch.executable, r'C:\Program Files\AgenticHive\hive-mcp.exe');
      expect(launch.baseArguments, isEmpty);
    });

    test('discovers companion binary on POSIX', () {
      final locator = HiveMcpLocator(
        binaryNaming: mcpBinaryNamingFor('linux'),
        resolvedExecutable: '/opt/agentic-hive/server',
        fileExists: (path) => path == '/opt/agentic-hive/hive-mcp',
        pathContext: p.posix,
      );

      final result = locator.resolve();
      expect(result.isSuccess, isTrue);
      final launch = result.valueOrNull!;
      expect(launch.executable, '/opt/agentic-hive/hive-mcp');
      expect(launch.baseArguments, isEmpty);
    });

    test('falls back to dart run in development mode when companion binary is '
        'absent', () {
      final locator = HiveMcpLocator(
        binaryNaming: mcpBinaryNamingFor('linux'),
        resolvedExecutable: '/usr/bin/dart',
        fileExists: (path) => path == '/repo/backend/bin/hive_mcp.dart',
        scriptPathOverride: '/repo/backend/bin/hive_mcp.dart',
        pathContext: p.posix,
      );

      final result = locator.resolve();
      expect(result.isSuccess, isTrue);
      final launch = result.valueOrNull!;
      expect(launch.executable, '/usr/bin/dart');
      expect(launch.baseArguments, const <String>[
        'run',
        '/repo/backend/bin/hive_mcp.dart',
      ]);
      expect(
        launch.argumentsFor(
          socketPath: '/tmp/backend.sock',
          runId: 'r1',
          nodeId: 'n1',
          attempt: 2,
        ),
        const <String>[
          'run',
          '/repo/backend/bin/hive_mcp.dart',
          '--socket',
          '/tmp/backend.sock',
          '--run-id',
          'r1',
          '--node-id',
          'n1',
          '--attempt',
          '2',
        ],
      );
    });

    test('returns NodeExecutionFailure when compiled binary has no companion '
        'hive-mcp executable', () {
      final locator = HiveMcpLocator(
        binaryNaming: mcpBinaryNamingFor('linux'),
        resolvedExecutable: '/opt/agentic-hive/server',
        fileExists: (_) => false,
        pathContext: p.posix,
      );

      final result = locator.resolve();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NodeExecutionFailure>());
    });

    test(
      r'discovers hive_mcp.exe beside backend\bin\server.exe (Bundle layout)',
      () {
        final locator = HiveMcpLocator(
          binaryNaming: mcpBinaryNamingFor('windows'),
          resolvedExecutable: r'C:\App\backend\bin\server.exe',
          fileExists: (path) => path == r'C:\App\backend\bin\hive_mcp.exe',
          pathContext: p.windows,
        );

        final result = locator.resolve();
        expect(result.isSuccess, isTrue);
        final launch = result.valueOrNull!;
        expect(launch.executable, r'C:\App\backend\bin\hive_mcp.exe');
        expect(launch.baseArguments, isEmpty);
      },
    );

    test(
      'discovers hive_mcp beside backend/bin/server on POSIX (Bundle layout)',
      () {
        final locator = HiveMcpLocator(
          binaryNaming: mcpBinaryNamingFor('linux'),
          resolvedExecutable: '/opt/agentic-hive/backend/bin/server',
          fileExists: (path) => path == '/opt/agentic-hive/backend/bin/hive_mcp',
          pathContext: p.posix,
        );

        final result = locator.resolve();
        expect(result.isSuccess, isTrue);
        final launch = result.valueOrNull!;
        expect(launch.executable, '/opt/agentic-hive/backend/bin/hive_mcp');
        expect(launch.baseArguments, isEmpty);
      },
    );
  });
}
