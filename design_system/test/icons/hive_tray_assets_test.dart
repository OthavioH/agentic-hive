import 'dart:io';
import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

const _prefix = 'packages/design_system/';

/// Reads the file behind a `packages/design_system/...` asset key.
Uint8List _bytes(String key) {
  expect(key, startsWith(_prefix));
  return File(key.substring(_prefix.length)).readAsBytesSync();
}

/// Width and height from a PNG's IHDR chunk.
(int, int) _pngSize(Uint8List bytes) {
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  expect(bytes.sublist(0, 8), signature);
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

/// Color type from a PNG's IHDR chunk (6 is RGBA).
int _pngColorType(Uint8List bytes) => bytes[25];

void main() {
  group('HiveTrayAssets', () {
    test('every key points at a bundled file under assets/tray', () {
      for (final key in HiveTrayAssets.all) {
        expect(key, startsWith('${_prefix}assets/tray/'));
        expect(File(key.substring(_prefix.length)).existsSync(), isTrue);
      }
    });

    test('the asset folder is declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/tray/'));
    });

    test('Windows icon is a multi-size .ico with 16 and 32 pixel images', () {
      final data = ByteData.sublistView(_bytes(HiveTrayAssets.windows));
      expect(data.getUint16(0, Endian.little), 0);
      expect(data.getUint16(2, Endian.little), 1);
      final count = data.getUint16(4, Endian.little);
      final sizes = <int>{
        for (var i = 0; i < count; i++) data.getUint8(6 + i * 16),
      };
      expect(sizes, containsAll(<int>[16, 20, 24, 32]));
    });

    test('Linux icons are RGBA PNGs at 32 and 64 pixels', () {
      final base = _bytes(HiveTrayAssets.linux);
      final hiDpi = _bytes(HiveTrayAssets.linux2x);
      expect(_pngSize(base), (32, 32));
      expect(_pngSize(hiDpi), (64, 64));
      expect(_pngColorType(base), 6);
    });

    test('macOS template icons are RGBA PNGs at 22 and 44 pixels', () {
      final base = _bytes(HiveTrayAssets.macosTemplate);
      final retina = _bytes(HiveTrayAssets.macosTemplate2x);
      expect(_pngSize(base), (22, 22));
      expect(_pngSize(retina), (44, 44));
      expect(_pngColorType(retina), 6);
    });
  });
}
