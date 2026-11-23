import 'package:test/test.dart';

import '../../../tool/src/bundle/server_info.dart';

void main() {
  group('ServerInfo.parse', () {
    test('parses the real server.json format', () {
      const source =
          '{"pid": 1234, "version": "0.1.0", '
          r'"socketPath": "C:\\d\\backend.sock", '
          '"startedAt": "2026-11-22T22:10:21.554996Z"}';

      final info = ServerInfo.parse(source);

      expect(info.pid, 1234);
      expect(info.socketPath, r'C:\d\backend.sock');
    });

    test('not JSON throws FormatException', () {
      expect(() => ServerInfo.parse('nope'), throwsFormatException);
    });

    test('missing socketPath throws FormatException', () {
      expect(() => ServerInfo.parse('{"pid": 1}'), throwsFormatException);
    });

    test('socketPath not a string throws FormatException', () {
      expect(
        () => ServerInfo.parse('{"pid": 1, "socketPath": 5}'),
        throwsFormatException,
      );
    });

    test('empty socketPath throws FormatException', () {
      expect(
        () => ServerInfo.parse('{"pid": 1, "socketPath": ""}'),
        throwsFormatException,
      );
    });
  });
}
