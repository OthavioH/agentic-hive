import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/config_loader.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Platform paths whose default data folder is a fixed, fake location.
final class _FakePlatformPaths implements PlatformPaths {
  new(this._defaultDataDir);

  final String _defaultDataDir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => _defaultDataDir;

  @override
  String homeDir() => p.join(p.dirname(_defaultDataDir), 'home');

  @override
  int get maxSocketPathBytes => 107;

  @override
  Future<void> restrictToOwner(String directory) async {}
}

Matcher _configErrorContaining(String text) =>
    isA<ConfigException>().having((e) => e.message, 'message', contains(text));

void main() {
  late Directory tempDir;
  late String defaultDataDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('config_loader_test_');
    defaultDataDir = p.join(tempDir.path, 'default-data');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  String writeYaml(String relativePath, String contents) {
    final file = File(p.join(tempDir.path, relativePath))
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
    return file.path;
  }

  ConfigLoader loader({
    RuntimeMode mode = RuntimeMode.development,
    List<String> devConfigCandidates = const [],
  }) => ConfigLoader(
    mode: mode,
    platformPaths: _FakePlatformPaths(defaultDataDir),
    devConfigCandidates: devConfigCandidates,
  );

  Future<AppConfig> loadFile(String yaml) =>
      loader().load(configPath: writeYaml('config.yaml', yaml));

  group('without a configuration file', () {
    test('uses the defaults and the platform data folder', () async {
      final config = await loader().load();

      expect(config.mode, RuntimeMode.development);
      expect(config.dataDir, p.normalize(defaultDataDir));
      expect(config.webSocketPingInterval, AppConfig.defaultPingInterval);
      expect(config.logRetentionDays, AppConfig.defaultLogRetentionDays);
    });

    test('uses ~/.agents/agents as the global agents folder', () async {
      final config = await loader().load();

      expect(
        config.agentsDir,
        p.join(p.dirname(defaultDataDir), 'home', '.agents', 'agents'),
      );
      expect(config.legacyAgentsDir, p.join(config.dataDir, 'agents'));
    });

    test('uses the defaults when no dev candidate exists', () async {
      final config = await loader(
        devConfigCandidates: [p.join(tempDir.path, 'missing.yaml')],
      ).load();

      expect(config.logRetentionDays, AppConfig.defaultLogRetentionDays);
      expect(config.dataDir, p.normalize(defaultDataDir));
    });

    test('treats an empty file as the defaults', () async {
      final config = await loadFile('');

      expect(config.webSocketPingInterval, AppConfig.defaultPingInterval);
      expect(config.logRetentionDays, AppConfig.defaultLogRetentionDays);
    });
  });

  group('file lookup', () {
    test('in development uses the first dev candidate that exists', () async {
      final first = writeYaml('a/dev.yaml', 'logs:\n  retention_days: 3\n');
      final second = writeYaml('b/dev.yaml', 'logs:\n  retention_days: 9\n');

      final config = await loader(
        devConfigCandidates: [
          p.join(tempDir.path, 'missing', 'dev.yaml'),
          first,
          second,
        ],
      ).load();

      expect(config.logRetentionDays, 3);
    });

    test('in production reads <default data dir>/config.yaml', () async {
      writeYaml(
        p.join('default-data', 'config.yaml'),
        'logs:\n  retention_days: 30\n',
      );

      final config = await loader(mode: RuntimeMode.production).load();

      expect(config.mode, RuntimeMode.production);
      expect(config.logRetentionDays, 30);
    });

    test('in production ignores the dev candidates', () async {
      final dev = writeYaml('dev.yaml', 'logs:\n  retention_days: 3\n');

      final config = await loader(
        mode: RuntimeMode.production,
        devConfigCandidates: [dev],
      ).load();

      expect(config.logRetentionDays, AppConfig.defaultLogRetentionDays);
    });

    test('--config wins over the dev candidates', () async {
      final dev = writeYaml('dev.yaml', 'logs:\n  retention_days: 3\n');
      final explicit = writeYaml(
        'explicit.yaml',
        'logs:\n  retention_days: 5\n',
      );

      final config = await loader(devConfigCandidates: [dev])
          .load(configPath: explicit);

      expect(config.logRetentionDays, 5);
    });

    test('--config pointing at a missing file throws a ConfigException', () {
      expect(
        loader().load(configPath: p.join(tempDir.path, 'nope.yaml')),
        throwsA(_configErrorContaining('config file not found')),
      );
    });
  });

  group('file validation', () {
    test('invalid YAML throws a ConfigException', () {
      expect(
        loadFile('paths: [unclosed\n'),
        throwsA(_configErrorContaining('is not valid YAML')),
      );
    });

    test('a root that is not a mapping throws a ConfigException', () {
      expect(
        loadFile('- a\n- b\n'),
        throwsA(_configErrorContaining('must contain a YAML mapping')),
      );
    });

    test('an unknown root key is named in the error', () {
      expect(
        loadFile('server:\n  port: 80\n'),
        throwsA(_configErrorContaining('unknown key "server"')),
      );
    });

    test('an unknown nested key is named as section.key', () {
      expect(
        loadFile('logs:\n  retention: 3\n'),
        throwsA(_configErrorContaining('unknown key "logs.retention"')),
      );
    });

    test('a section that is not a mapping is named in the error', () {
      expect(
        loadFile('websocket: 20\n'),
        throwsA(_configErrorContaining('"websocket" must be a mapping')),
      );
    });

    test('the error message names the file', () async {
      final path = writeYaml('named.yaml', 'bogus: 1\n');

      await expectLater(
        loader().load(configPath: path),
        throwsA(_configErrorContaining(File(path).absolute.path)),
      );
    });

    test('ConfigException.toString starts with "Invalid configuration"', () {
      expect(const ConfigException('x').toString(), 'Invalid configuration: x');
    });
  });

  group('websocket.ping_interval_seconds', () {
    for (final value in [1, 300]) {
      test('accepts $value', () async {
        final config = await loadFile(
          'websocket:\n  ping_interval_seconds: $value\n',
        );

        expect(config.webSocketPingInterval, Duration(seconds: value));
      });
    }

    for (final value in ['0', '301', '-5', '1.5', '"20"', 'abc']) {
      test('rejects $value', () {
        expect(
          loadFile('websocket:\n  ping_interval_seconds: $value\n'),
          throwsA(
            _configErrorContaining(
              '"websocket.ping_interval_seconds" must be an integer from 1 '
              'to 300',
            ),
          ),
        );
      });
    }
  });

  group('logs.retention_days', () {
    for (final value in [1, 365]) {
      test('accepts $value', () async {
        final config = await loadFile('logs:\n  retention_days: $value\n');

        expect(config.logRetentionDays, value);
      });
    }

    for (final value in ['0', '366', '7.0', 'true', 'seven']) {
      test('rejects $value', () {
        expect(
          loadFile('logs:\n  retention_days: $value\n'),
          throwsA(
            _configErrorContaining(
              '"logs.retention_days" must be an integer from 1 to 365',
            ),
          ),
        );
      });
    }
  });

  group('paths.data_dir', () {
    test('is resolved against the config file folder', () async {
      final path = writeYaml(
        p.join('cfg', 'config.yaml'),
        'paths:\n  data_dir: ../my-data\n',
      );

      final config = await loader().load(configPath: path);

      expect(config.dataDir, p.normalize(p.join(tempDir.path, 'my-data')));
    });

    test('keeps an absolute path as is', () async {
      final absolute = p.join(tempDir.path, 'abs-data');

      final config = await loadFile("paths:\n  data_dir: '$absolute'\n");

      expect(config.dataDir, p.normalize(absolute));
    });

    for (final value in ["''", "'   '", '5', '[a]']) {
      test('rejects $value', () {
        expect(
          loadFile('paths:\n  data_dir: $value\n'),
          throwsA(
            _configErrorContaining('"paths.data_dir" must be a non-empty'),
          ),
        );
      });
    }

    test('dataDirOverride wins over the file and the default', () async {
      final path = writeYaml('config.yaml', 'paths:\n  data_dir: from-file\n');
      final override = p.join(tempDir.path, 'override');

      final config = await loader().load(
        configPath: path,
        dataDirOverride: override,
      );

      expect(config.dataDir, p.normalize(override));
    });

    test('a relative dataDirOverride is made absolute', () async {
      final config = await loader().load(dataDirOverride: 'rel-data');

      expect(p.isAbsolute(config.dataDir), isTrue);
      expect(config.dataDir, p.normalize(p.absolute('rel-data')));
    });
  });

  test('reads every key of a complete file', () async {
    final config = await loadFile('''
# A full configuration.
paths:
  data_dir: data
websocket:
  ping_interval_seconds: 45
logs:
  retention_days: 7
''');

    expect(config.dataDir, p.normalize(p.join(tempDir.path, 'data')));
    expect(config.webSocketPingInterval, const Duration(seconds: 45));
    expect(config.logRetentionDays, 7);
  });
}
