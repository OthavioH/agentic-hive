import 'package:agentic_hive_backend/src/api/agents/agents_migration_handler.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agents_migration_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _MemorySettings implements SettingsRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<Result<Map<String, String>>> getAll() async =>
      Success(Map<String, String>.of(values));

  @override
  Future<Result<void>> applyChanges(Map<String, String?> changes) async {
    changes.forEach((key, value) {
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
    });
    return const Success(null);
  }
}

void main() {
  late Handler handler;

  setUp(() {
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 1),
        ),
        version: '0.1.0',
        dataDir: '.',
        startedAt: DateTime.utc(2026, 11, 20),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response(418),
      agentsMigrationHandler: AgentsMigrationHandler(
        AgentsMigrationService(
          legacyDir: '/data/agents',
          targetDir: '/home/me/.agents/agents',
          conflicts: const ['a.md'],
          settings: _MemorySettings(),
        ),
      ),
    );
  });

  test('GET reports the conflicts of the agents move', () async {
    final response = await handler(
      buildRequest('/api/v1/agent-library/migration'),
    );

    expect(response.statusCode, 200);
    final status = AgentsMigrationStatus.fromJson(await readJson(response));
    expect(status.conflicts, ['a.md']);
    expect(status.dismissed, isFalse);
  });

  test('POST dismiss acknowledges the conflicts', () async {
    final dismissed = await handler(
      buildRequest('/api/v1/agent-library/migration/dismiss', method: 'POST'),
    );
    expect(dismissed.statusCode, 200);
    expect(
      AgentsMigrationStatus.fromJson(await readJson(dismissed)).dismissed,
      isTrue,
    );

    final again = await handler(
      buildRequest('/api/v1/agent-library/migration'),
    );
    expect(
      AgentsMigrationStatus.fromJson(await readJson(again)).hasPendingConflicts,
      isFalse,
    );
  });
}
