@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io' as io;
import 'dart:io' show Directory, File, FileSystemEntity, Platform, Process;

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late String dataDir;

  setUp(() async {
    dataDir = (await createTempDir()).path;
  });

  group('server.json and socket file', () {
    test(
      'exist after start with pid, version, socketPath and startedAt',
      () async {
        final before = DateTime.now().toUtc().subtract(
          const Duration(seconds: 1),
        );
        final backend = await startBackend(dataDir);

        expect(backend.socketPath, socketPathIn(dataDir));
        expect(
          FileSystemEntity.typeSync(backend.socketPath, followLinks: false),
          io.FileSystemEntityType.unixDomainSock,
        );

        final info = jsonDecode(
          File(serverInfoPathIn(dataDir)).readAsStringSync(),
        ) as JsonMap;
        expect(info['pid'], io.pid);
        expect(info['version'], backendVersion);
        expect(info['socketPath'], backend.socketPath);
        final startedAt = DateTime.parse(info['startedAt']! as String);
        expect(startedAt.isUtc, isTrue);
        expect(startedAt.isAfter(before), isTrue);
        expect(startedAt.isBefore(DateTime.now().toUtc()), isTrue);
        expect(File('${serverInfoPathIn(dataDir)}.tmp').existsSync(), isFalse);
      },
    );

    test('stop() removes both, and a second stop() does not throw', () async {
      final backend = await startBackend(dataDir, stopOnTearDown: false);
      // Backend.socketPath resolves through the container, which stop()
      // resets, so read it while the backend runs.
      final socketPath = backend.socketPath;
      expect(entityExists(socketPath), isTrue);
      expect(entityExists(serverInfoPathIn(dataDir)), isTrue);

      await backend.stop().timeout(ioTimeout);

      expect(entityExists(socketPath), isFalse);
      expect(entityExists(serverInfoPathIn(dataDir)), isFalse);
      await expectLater(backend.stop().timeout(ioTimeout), completes);
    });

    test('the socket stops answering after stop()', () async {
      final backend = await startBackend(dataDir, stopOnTearDown: false);
      final client = openClient(backend.socketPath);
      expect((await client.get('/health')).statusCode, 200);

      await backend.stop().timeout(ioTimeout);

      final fresh = openClient(socketPathIn(dataDir));
      await expectLater(
        fresh.get('/health'),
        throwsA(isA<io.SocketException>()),
      );
    });

    test(
      'POST /api/v1/shutdown answers 202 and removes server.json and socket',
      () async {
        final backend = await startBackend(dataDir, stopOnTearDown: false);
        final socketPath = backend.socketPath;
        final client = openClient(socketPath);

        final response = await client.post(
          '/api/v1/shutdown',
          body: jsonEncode(const ShutdownRequest()),
        );

        expect(response.statusCode, 202);
        expect(
          ShutdownResponse.fromJson(response.json).status,
          'shutting_down',
        );

        await backend.done.timeout(ioTimeout);
        expect(entityExists(socketPath), isFalse);
        expect(entityExists(serverInfoPathIn(dataDir)), isFalse);

        final fresh = openClient(socketPathIn(dataDir));
        await expectLater(
          fresh.get('/health'),
          throwsA(isA<io.SocketException>()),
        );
      },
    );
  });

  group('single backend per data folder', () {
    test('a second start throws BackendAlreadyRunningException and the first '
        'keeps serving', () async {
      final first = await startBackend(dataDir);
      final client = openClient(first.socketPath);
      final infoBefore = File(serverInfoPathIn(dataDir)).readAsStringSync();

      await expectLater(
        startBackend(dataDir),
        throwsA(
          isA<BackendAlreadyRunningException>().having(
            (e) => e.socketPath,
            'socketPath',
            first.socketPath,
          ),
        ),
      );

      expect(entityExists(first.socketPath), isTrue);
      expect(File(serverInfoPathIn(dataDir)).readAsStringSync(), infoBefore);
      final health = await client.get('/health');
      expect(health.statusCode, 200);
      final status = await client.get('/api/v1/status');
      expect(status.statusCode, 200);
      expect(StatusResponse.fromJson(status.json).database.ok, isTrue);
    });
  });

  group('stale socket', () {
    test(
      'a socket left by a killed process is cleared and start succeeds',
      () async {
        await _leaveStaleSocket(socketPathIn(dataDir));
        expect(
          FileSystemEntity.typeSync(socketPathIn(dataDir), followLinks: false),
          io.FileSystemEntityType.unixDomainSock,
        );

        final backend = await startBackend(dataDir);

        final response = await openClient(backend.socketPath).get('/health');
        expect(response.statusCode, 200);
      },
      tags: 'flaky',
    );

    test(
      'a regular file at the socket path is cleared and start succeeds',
      () async {
        File(socketPathIn(dataDir)).writeAsStringSync('stale');

        final backend = await startBackend(dataDir);

        final response = await openClient(backend.socketPath).get('/health');
        expect(response.statusCode, 200);
      },
    );
  });

  group('socket path limit', () {
    final maxBytes = currentPlatformPaths().maxSocketPathBytes;

    test('a socket path one byte over the limit throws '
        'SocketPathTooLongException', () async {
      final longDir = _dataDirWithSocketLength(dataDir, maxBytes + 1);

      await expectLater(
        startBackend(longDir),
        throwsA(
          isA<SocketPathTooLongException>()
              .having((e) => e.maxBytes, 'maxBytes', maxBytes)
              .having(
                (e) => utf8.encode(e.socketPath).length,
                'socketPath bytes',
                maxBytes + 1,
              ),
        ),
      );
      expect(entityExists(socketPathIn(longDir)), isFalse);
      expect(entityExists(serverInfoPathIn(longDir)), isFalse);
    });

    test('a socket path exactly at the limit starts and serves', () async {
      final longDir = _dataDirWithSocketLength(dataDir, maxBytes);

      final backend = await startBackend(longDir);

      expect(utf8.encode(backend.socketPath).length, maxBytes);
      final response = await openClient(backend.socketPath).get('/health');
      expect(response.statusCode, 200);
    });
  });

  group('data folder permissions', () {
    test(
      'the data folder is rwx------ after start',
      () async {
        final nested = p.join(dataDir, 'd');
        await startBackend(nested);

        expect(Directory(nested).statSync().modeString(), 'rwx------');
      },
      skip: Platform.isWindows
          ? 'Windows relies on the user profile ACL, not POSIX modes '
                '(ADR 0011).'
          : false,
    );
  });
}

/// A data folder under [parent] whose `backend.sock` path is exactly
/// [socketBytes] bytes long.
String _dataDirWithSocketLength(String parent, int socketBytes) {
  final base = socketPathIn(p.join(parent, 'x'));
  final padding = socketBytes - utf8.encode(base).length;
  if (padding < 0) {
    fail('The temporary folder is too long to build this path: $base');
  }
  return p.join(parent, 'x' * (1 + padding));
}

/// Leaves a real stale socket file at [socketPath]: a child Dart process binds
/// it and is killed, so nobody unlinks it.
Future<void> _leaveStaleSocket(String socketPath) async {
  final script = File(p.join(p.dirname(socketPath), 'hold.dart'))
    ..writeAsStringSync('''
import 'dart:io';

Future<void> main(List<String> args) async {
  await ServerSocket.bind(
    InternetAddress(args.single, type: InternetAddressType.unix),
    0,
  );
  print('ready');
}
''');
  final process = await Process.start(Platform.resolvedExecutable, [
    script.path,
    socketPath,
  ]);
  try {
    process.stderr.drain<void>().ignore();
    await process.stdout
        .transform(utf8.decoder)
        .firstWhere((chunk) => chunk.contains('ready'))
        .timeout(const Duration(seconds: 30));
  } finally {
    process.kill(io.ProcessSignal.sigkill);
    await process.exitCode.timeout(ioTimeout);
  }
}
