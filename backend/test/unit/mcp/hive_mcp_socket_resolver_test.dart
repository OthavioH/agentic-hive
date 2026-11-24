import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/config_loader.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_resolver.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('HiveMcpSocketResolver', () {
    test('explicit socket wins without loading config', () async {
      var loads = 0;
      final resolver = HiveMcpSocketResolver(
        loadConfig: () async {
          loads++;
          throw StateError('must not load');
        },
      );

      final result = await resolver.resolve(explicitSocket: '/tmp/x.sock');

      expect((result as Success<String>).value, '/tmp/x.sock');
      expect(loads, 0);
    });

    test('falls back to the loaded config socket path', () async {
      final dataDir = p.join(p.current, 'data');
      final resolver = HiveMcpSocketResolver(
        loadConfig: () async =>
            AppConfig(mode: RuntimeMode.development, dataDir: dataDir),
      );

      final result = await resolver.resolve();

      expect(
        (result as Success<String>).value,
        p.join(dataDir, 'backend.sock'),
      );
    });

    test('config errors become a failure, never a throw', () async {
      final loaders = <Future<AppConfig> Function()>[
        () async => throw const ConfigException('bad'),
        () async => throw StateError('no env'),
      ];
      for (final loader in loaders) {
        final resolver = HiveMcpSocketResolver(loadConfig: loader);

        expect(await resolver.resolve(), isA<FailureResult<String>>());
      }
    });
  });
}
