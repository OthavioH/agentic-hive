import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_repository_impl.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Result<JsonMap> nextGet = const Success(<String, Object?>{'notice': null});
  Result<void> nextDelete = const Success<void>(null);
  final List<String> getPaths = <String>[];
  final List<String> deletePaths = <String>[];

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async {
    getPaths.add(path);
    return nextGet;
  }

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async => const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<void>> delete(String path) async {
    deletePaths.add(path);
    return nextDelete;
  }

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async => const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

void main() {
  final sampleNotice = SkillAutoInstallNotice(
    id: 'notice-1',
    createdAt: DateTime.utc(2026, 11, 20, 12),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.claude/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
    ],
  );

  group('SkillNoticeRemoteDataSource', () {
    test('getPendingNotice maps {"notice": null} to Success(null)', () async {
      final client = _FakeBackendClient()
        ..nextGet = const Success(<String, Object?>{'notice': null});
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final ds = SkillNoticeRemoteDataSourceImpl(
        client: client,
        wsMessages: ws.stream,
      );

      final result = await ds.getPendingNotice();
      expect(client.getPaths, <String>['/api/v1/skills/auto-install/notice']);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('getPendingNotice decodes a full notice payload', () async {
      final client = _FakeBackendClient()
        ..nextGet = Success(
          SkillAutoInstallNoticeResponse(notice: sampleNotice).toJson(),
        );
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final ds = SkillNoticeRemoteDataSourceImpl(
        client: client,
        wsMessages: ws.stream,
      );

      final result = await ds.getPendingNotice();
      expect(result.valueOrNull, sampleNotice);
    });

    test(
      'dismissNotice calls DELETE /api/v1/skills/auto-install/notice',
      () async {
        final client = _FakeBackendClient();
        final ws = StreamController<WsEnvelope>.broadcast();
        addTearDown(ws.close);

        final repo = SkillNoticeRepositoryImpl(
          SkillNoticeRemoteDataSourceImpl(
            client: client,
            wsMessages: ws.stream,
          ),
        );

        final result = await repo.dismissNotice();
        expect(result.isSuccess, isTrue);
        expect(client.deletePaths, <String>[
          '/api/v1/skills/auto-install/notice',
        ]);
      },
    );

    test('watchNotices ignores unrelated and malformed frames and emits valid '
        'notice', () async {
      final client = _FakeBackendClient();
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final ds = SkillNoticeRemoteDataSourceImpl(
        client: client,
        wsMessages: ws.stream,
      );

      final received = <SkillAutoInstallNotice>[];
      final sub = ds.watchNotices().listen(received.add);
      addTearDown(sub.cancel);

      ws
        ..add(const WsEnvelope(type: WsMessageType.serverHello, id: '1'))
        ..add(
          const WsEnvelope(
            type: WsMessageType.skillsAutoInstalled,
            id: '2',
            payload: <String, Object?>{'invalid': true},
          ),
        )
        ..add(
          WsEnvelope(
            type: WsMessageType.skillsAutoInstalled,
            id: '3',
            payload: SkillAutoInstallNoticePayload(notice: sampleNotice)
                .toJson(),
          ),
        );

      await pumpEventQueue();
      expect(received, <SkillAutoInstallNotice>[sampleNotice]);
    });
  });
}
