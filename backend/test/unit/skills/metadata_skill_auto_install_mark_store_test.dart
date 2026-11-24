import 'package:agentic_hive_backend/src/data/skills/metadata_skill_auto_install_mark_store.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late MetadataRepository metadata;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    metadata = DriftMetadataRepository(db);
  });

  tearDown(() => db.close());

  test(
    'fresh DB is unmarked, mark persists across instances with UTC ISO-8601',
    () async {
      final fixedNow = DateTime.utc(2026, 11, 24, 15, 30);
      final store = MetadataSkillAutoInstallMarkStore(
        metadata,
        now: () => fixedNow,
      );

      for (final id in HarnessId.values) {
        expect(await store.isMarked(id), isFalse);
      }

      await store.mark(HarnessId.codex);
      expect(await store.isMarked(HarnessId.codex), isTrue);
      expect(await store.isMarked(HarnessId.claudeCode), isFalse);

      final raw = await metadata.read(
        '${MetadataSkillAutoInstallMarkStore.markKeyPrefix}codex',
      );
      expect(raw, fixedNow.toIso8601String());
      expect(DateTime.parse(raw!).isUtc, isTrue);

      final secondStore = MetadataSkillAutoInstallMarkStore(metadata);
      expect(await secondStore.isMarked(HarnessId.codex), isTrue);

      await secondStore.mark(HarnessId.codex);
      expect(await secondStore.isMarked(HarnessId.codex), isTrue);
    },
  );
}
