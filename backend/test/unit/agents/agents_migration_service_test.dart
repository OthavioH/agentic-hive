import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agents_migration_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:test/test.dart';

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

AgentsMigrationService _service(
  _MemorySettings settings,
  List<String> conflicts,
) => AgentsMigrationService(
  legacyDir: '/data/agents',
  targetDir: '/home/me/.agents/agents',
  conflicts: conflicts,
  settings: settings,
);

void main() {
  late _MemorySettings settings;

  setUp(() => settings = _MemorySettings());

  test('reports the conflicts and the two folders, not dismissed', () async {
    final status = (await _service(settings, ['a.md']).status()).valueOrNull!;

    expect(status.conflicts, ['a.md']);
    expect(status.legacyDir, '/data/agents');
    expect(status.targetDir, '/home/me/.agents/agents');
    expect(status.dismissed, isFalse);
    expect(status.hasPendingConflicts, isTrue);
  });

  test('without conflicts there is nothing pending', () async {
    final status = (await _service(settings, const []).status()).valueOrNull!;

    expect(status.hasPendingConflicts, isFalse);
  });

  test('dismiss persists across restarts for the same conflicts', () async {
    final dismissed = (await _service(settings, [
      'a.md',
      'b.md',
    ]).dismiss()).valueOrNull!;
    expect(dismissed.dismissed, isTrue);

    final afterRestart = (await _service(settings, [
      'b.md',
      'a.md',
    ]).status()).valueOrNull!;
    expect(afterRestart.dismissed, isTrue);
    expect(afterRestart.hasPendingConflicts, isFalse);
  });

  test('a new set of conflicts is reported again after a dismissal', () async {
    await _service(settings, ['a.md']).dismiss();

    final status = (await _service(settings, [
      'a.md',
      'c.md',
    ]).status()).valueOrNull!;

    expect(status.dismissed, isFalse);
    expect(status.hasPendingConflicts, isTrue);
  });
}
