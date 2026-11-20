import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/server/local_socket.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('LocalSocket.prepare', () {
    test('rejects a path longer than maxPathBytes', () async {
      final socket = LocalSocket('a' * 11, maxPathBytes: 10);

      await expectLater(
        socket.prepare(),
        throwsA(
          isA<SocketPathTooLongException>()
              .having((e) => e.socketPath, 'socketPath', 'a' * 11)
              .having((e) => e.maxBytes, 'maxBytes', 10),
        ),
      );
    });

    test('counts UTF-8 bytes, not characters', () async {
      // Six characters, twelve bytes.
      final socket = LocalSocket('é' * 6, maxPathBytes: 10);

      await expectLater(
        socket.prepare(),
        throwsA(isA<SocketPathTooLongException>()),
      );
    });

    test(
      'accepts a path of exactly maxPathBytes that does not exist',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('local_socket_');
        addTearDown(() => tempDir.delete(recursive: true));
        final path = p.join(tempDir.path, 'backend.sock');

        final socket = LocalSocket(
          path,
          maxPathBytes: utf8.encode(path).length,
        );

        await expectLater(socket.prepare(), completes);
      },
    );
  });

  test('SocketPathTooLongException names the limit and the path', () {
    expect(
      const SocketPathTooLongException('/x/backend.sock', 103).toString(),
      allOf(contains('103 bytes'), contains('/x/backend.sock')),
    );
  });
}
