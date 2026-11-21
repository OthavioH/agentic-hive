import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/get_settings.dart';
import 'package:agentic_hive_frontend/domain/settings/pick_directory.dart';
import 'package:agentic_hive_frontend/domain/settings/pick_file.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/update_settings.dart';
import 'package:agentic_hive_frontend/domain/settings/watch_settings_updates.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeSettingsRepository implements SettingsRepository {
  Result<AppSettings> getResult = const Success(
    AppSettings(
      agentsDir: '/default/agents',
      defaultAgentsDir: '/default/agents',
    ),
  );
  Result<AppSettings> updateResult = const Success(
    AppSettings(
      agentsDir: '/custom/agents',
      defaultAgentsDir: '/default/agents',
    ),
  );
  UpdateSettingsRequest? lastRequest;
  final StreamController<AppSettings> updates =
      StreamController<AppSettings>.broadcast();

  @override
  Future<Result<AppSettings>> getSettings() async => getResult;

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async {
    lastRequest = request;
    return updateResult;
  }

  @override
  Stream<AppSettings> watchSettingsUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

final class _FakeFilePickerRepository implements FilePickerRepository {
  String? directoryResult = '/picked/dir';
  String? fileResult = '/picked/file';
  String? lastInitialDirectory;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    lastInitialDirectory = initialDirectory;
    return directoryResult;
  }

  @override
  Future<String?> pickFile({String? initialDirectory}) async {
    lastInitialDirectory = initialDirectory;
    return fileResult;
  }
}

void main() {
  group('Settings use cases', () {
    test(
      'GetSettings, UpdateSettings, WatchSettingsUpdates delegate cleanly',
      () async {
        final repo = _FakeSettingsRepository();
        addTearDown(repo.dispose);

        const updated = AppSettings(
          agentsDir: '/custom/agents',
          defaultAgentsDir: '/default/agents',
        );
        const request = UpdateSettingsRequest(agentsDir: '/custom/agents');

        expect(
          (await GetSettings(repo)()).valueOrNull?.agentsDir,
          '/default/agents',
        );
        expect((await UpdateSettings(repo)(request)).valueOrNull, updated);
        expect(repo.lastRequest, request);

        final received = <AppSettings>[];
        final sub = WatchSettingsUpdates(repo)().listen(received.add);
        addTearDown(sub.cancel);
        repo.updates.add(updated);
        await Future<void>.delayed(Duration.zero);
        expect(received, <AppSettings>[updated]);
      },
    );

    test(
      'PickDirectory and PickFile delegate to FilePickerRepository',
      () async {
        final picker = _FakeFilePickerRepository();

        expect(
          await PickDirectory(picker)(initialDirectory: '/start'),
          '/picked/dir',
        );
        expect(picker.lastInitialDirectory, '/start');

        expect(
          await PickFile(picker)(initialDirectory: '/bin'),
          '/picked/file',
        );
        expect(picker.lastInitialDirectory, '/bin');
      },
    );
  });
}
