import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/harnesses/harnesses_remote_data_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Result<JsonMap> nextPost = const Success(<String, Object?>{});
  Result<JsonMap> nextSendJson = const Success(<String, Object?>{});
  final List<String> postPaths = <String>[];
  final List<({String method, String path})> sentRequests =
      <({String method, String path})>[];

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
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async {
    postPaths.add(path);
    return nextPost;
  }

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<void>> delete(String path) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    sentRequests.add((method: method, path: path));
    return nextSendJson;
  }

  @override
  Future<void> close() async {}
}

void main() {
  final claude = HarnessInfo(
    id: HarnessId.claudeCode,
    displayName: 'Claude Code',
    status: HarnessStatus.ready,
    skillStatus: HarnessSkillStatus.installed,
    checkedAt: DateTime.utc(2026, 11, 20),
  );

  group('HarnessesRemoteDataSource skill endpoints', () {
    test(
      'installSkill passes overwriteModified=false and true with id wireName',
      () async {
        final client = _FakeBackendClient()
          ..nextPost = Success(claude.toJson());
        final ws = StreamController<WsEnvelope>.broadcast();
        addTearDown(ws.close);

        final ds = HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: ws.stream,
        );

        final first = await ds.installSkill(
          HarnessId.claudeCode,
          overwriteModified: false,
        );
        final second = await ds.installSkill(
          HarnessId.geminiCli,
          overwriteModified: true,
        );

        expect(client.postPaths, <String>[
          '/api/v1/harnesses/claude_code/skill/install?overwriteModified=false',
          '/api/v1/harnesses/gemini_cli/skill/install?overwriteModified=true',
        ]);
        expect(first.valueOrNull, claude);
        expect(second.valueOrNull, claude);
      },
    );

    test('removeSkill sends DELETE /api/v1/harnesses/:id/skill and decodes '
        'HarnessInfo', () async {
      final removed = claude.copyWith(
        skillStatus: HarnessSkillStatus.notInstalled,
      );
      final client = _FakeBackendClient()
        ..nextSendJson = Success(removed.toJson());
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final repo = HarnessRepositoryImpl(
        HarnessesRemoteDataSourceImpl(client: client, wsMessages: ws.stream),
      );

      final result = await repo.removeSkill(HarnessId.claudeCode);
      expect(client.sentRequests, <({String method, String path})>[
        (method: 'DELETE', path: '/api/v1/harnesses/claude_code/skill'),
      ]);
      expect(result.valueOrNull, removed);
    });

    test(
      'maps 409 response to ConflictFailure for installSkill and removeSkill',
      () async {
        final client = _FakeBackendClient()
          ..nextPost = const FailureResult(
            BackendFailure(
              'Modified on disk.',
              code: ApiErrorCode.conflict,
              statusCode: 409,
            ),
          )
          ..nextSendJson = const FailureResult(
            BackendFailure(
              'Foreign folder.',
              code: ApiErrorCode.conflict,
              statusCode: 409,
            ),
          );
        final ws = StreamController<WsEnvelope>.broadcast();
        addTearDown(ws.close);

        final ds = HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: ws.stream,
        );

        final installRes = await ds.installSkill(
          HarnessId.codex,
          overwriteModified: false,
        );
        expect(
          installRes.failureOrNull,
          isA<ConflictFailure>().having(
            (f) => f.message,
            'message',
            'Modified on disk.',
          ),
        );

        final removeRes = await ds.removeSkill(HarnessId.codex);
        expect(
          removeRes.failureOrNull,
          isA<ConflictFailure>().having(
            (f) => f.message,
            'message',
            'Foreign folder.',
          ),
        );
      },
    );
  });
}
