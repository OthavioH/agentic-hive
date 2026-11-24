import 'package:path/path.dart' as p;

/// Returns the `config/dev.yaml` next to the package that holds [script], or
/// `null` when [script] is not a Dart source file (a compiled executable).
String? scriptRelativeDevConfig(Uri script) {
  if (!script.isScheme('file') || !script.path.endsWith('.dart')) {
    return null;
  }
  return p.join(
    p.dirname(p.dirname(script.toFilePath())),
    'config',
    'dev.yaml',
  );
}
