import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final dataDir = p.join(p.rootPrefix(p.current), 'hive-data');

  AppConfig configFor(RuntimeMode mode) =>
      AppConfig(mode: mode, dataDir: dataDir);

  group('AppConfig', () {
    test('derives every path from the data folder', () {
      final config = configFor(RuntimeMode.development);

      expect(config.socketPath, p.join(dataDir, 'backend.sock'));
      expect(config.databasePath, p.join(dataDir, 'hive.db'));
      expect(config.logsDir, p.join(dataDir, 'logs'));
      expect(config.serverInfoPath, p.join(dataDir, 'server.json'));
    });

    test('logs at FINE in development', () {
      expect(configFor(RuntimeMode.development).logLevel, Level.FINE);
    });

    test('logs at INFO in production', () {
      expect(configFor(RuntimeMode.production).logLevel, Level.INFO);
    });

    test('defaults to a 20 s ping interval and 14 days of logs', () {
      final config = configFor(RuntimeMode.production);

      expect(config.webSocketPingInterval, const Duration(seconds: 20));
      expect(config.logRetentionDays, 14);
    });
  });
}
