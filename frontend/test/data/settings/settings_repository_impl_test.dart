import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/settings/settings_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  JsonMap? lastBody;
  Result<JsonMap> nextResult = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    return nextResult;
  }

  @override
  Future<Result<StatusResponse>> checkStatus() => throw UnimplementedError();

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String path) => throw UnimplementedError();

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) =>
      throw UnimplementedError();

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) => throw UnimplementedError();

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) =>
      throw UnimplementedError();

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {}
}

void main() {
  const sampleSettings = AppSettings(
    agentsDir: '/custom/agents',
    effectiveAgentsDir: '/custom/agents',
    defaultAgentsDir: '/default/agents',
    harnessOverrides: <HarnessId, String>{
      HarnessId.claudeCode: '/usr/local/bin/claude',
    },
  );

  group('SettingsRepositoryImpl', () {
    late _FakeBackendClient client;
    late StreamController<WsEnvelope> wsController;
    late SettingsRepositoryImpl repository;

    setUp(() {
      client = _FakeBackendClient();
      wsController = StreamController<WsEnvelope>.broadcast();
      final dataSource = SettingsRemoteDataSourceImpl(
        client: client,
        wsMessages: wsController.stream,
      );
      repository = SettingsRepositoryImpl(dataSource);
    });

    tearDown(() => wsController.close());

    test(
      'getSettings calls GET /api/v1/settings and decodes AppSettings',
      () async {
        client.nextResult = Success(sampleSettings.toJson());

        final result = await repository.getSettings();

        expect(client.lastMethod, 'GET');
        expect(client.lastPath, '/api/v1/settings');
        expect(result.valueOrNull, sampleSettings);
      },
    );

    test(
      'updateSettings calls PUT /api/v1/settings and preserves details',
      () async {
        const failure = ValidationFailure(
          'Settings validation failed.',
          details: <String, String>{
            'agentsDir': 'Agents folder does not exist.',
            'harnessOverrides.codex': 'Codex path is not executable.',
          },
        );
        client.nextResult = const FailureResult<JsonMap>(failure);

        const request = UpdateSettingsRequest(
          agentsDir: '/bad/agents',
          harnessOverrides: <HarnessId, String>{HarnessId.codex: '/bad/codex'},
        );
        final result = await repository.updateSettings(request);

        expect(client.lastMethod, 'PUT');
        expect(client.lastPath, '/api/v1/settings');
        expect(client.lastBody, request.toJson());
        expect(result, isA<FailureResult<AppSettings>>());
        final actualFailure = (result as FailureResult<AppSettings>).failure;
        expect(actualFailure, isA<ValidationFailure>());
        expect((actualFailure as ValidationFailure).details, failure.details);
      },
    );

    test(
      'watchSettingsUpdates emits decoded settings and ignores bad frames',
      () async {
        final emitted = <AppSettings>[];
        final sub = repository.watchSettingsUpdates().listen(emitted.add);
        addTearDown(sub.cancel);

        wsController
          ..add(
            const WsEnvelope(
              type: WsMessageType.harnessStatusUpdated,
              id: 'evt-1',
            ),
          )
          ..add(
            const WsEnvelope(
              type: WsMessageType.settingsUpdated,
              id: 'evt-2',
              payload: <String, Object?>{'invalid': true},
            ),
          )
          ..add(
            WsEnvelope(
              type: WsMessageType.settingsUpdated,
              id: 'evt-3',
              payload: const SettingsUpdatedPayload(settings: sampleSettings)
                  .toJson(),
            ),
          );

        await Future<void>.delayed(Duration.zero);
        expect(emitted, <AppSettings>[sampleSettings]);
      },
    );
  });
}
