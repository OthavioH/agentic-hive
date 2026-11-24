import 'package:agentic_hive_backend/src/config/dev_config_candidates.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('scriptRelativeDevConfig', () {
    test('dart script gives package config/dev.yaml', () {
      final script = Uri.file(p.join(p.current, 'backend', 'bin', 'x.dart'));

      expect(
        scriptRelativeDevConfig(script),
        p.join(p.current, 'backend', 'config', 'dev.yaml'),
      );
    });

    test('non-file or non-dart script gives null', () {
      expect(scriptRelativeDevConfig(Uri.parse('http://x/a.dart')), isNull);
      expect(scriptRelativeDevConfig(Uri.file(p.join(p.current, 'x'))), isNull);
    });
  });
}
