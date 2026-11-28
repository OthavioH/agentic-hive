import 'package:agentic_hive_frontend/core/backend/pty_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PtyPlatform', () {
    test('windows uses ConPTY', () {
      expect(ptyPlatformFor('windows').usesConPty, isTrue);
    });

    test('linux does not use ConPTY', () {
      expect(ptyPlatformFor('linux').usesConPty, isFalse);
    });

    test('macos does not use ConPTY', () {
      expect(ptyPlatformFor('macos').usesConPty, isFalse);
    });

    test('unsupported OS throws UnsupportedError', () {
      expect(() => ptyPlatformFor('fuchsia'), throwsUnsupportedError);
    });
  });
}
