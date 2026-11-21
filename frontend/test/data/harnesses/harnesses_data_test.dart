import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/harnesses/harnesses_remote_data_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Result<JsonMap> nextGet = const Success(<String, Object?>{});
  Result<JsonMap> nextPost = const Success(<String, Object?>{});
  final List<String> getPaths = <String>[];
  final List<String> postPaths = <String>[];

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

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
  }) async {
    postPaths.add(path);
    return nextPost;
  }

  @override
  Future<void> close() async {}
}

void main() {
  final claude = HarnessInfo(
    id: HarnessId.claudeCode,
    displayName: 'Claude Code',
    status: HarnessStatus.ready,
    version: '1.2.3',
    executablePath: r'C:\tools\claude.exe',
    checkedAt: DateTime.utc(2026, 11, 20),
  );

  group('HarnessesRemoteDataSourceImpl', () {
    test(
      'getHarnesses requests GET /api/v1/harnesses and decodes list',
      () async {
        final client = _FakeBackendClient()
          ..nextGet = Success(
            HarnessListResponse(harnesses: <HarnessInfo>[claude]).toJson(),
          );
        final controller = StreamController<WsEnvelope>.broadcast();
        addTearDown(controller.close);

        final ds = HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: controller.stream,
        );

        final result = await ds.getHarnesses();
        expect(client.getPaths, <String>['/api/v1/harnesses']);
        expect(result.valueOrNull?.harnesses, <HarnessInfo>[claude]);
      },
    );

    test('refreshAll requests POST /api/v1/harnesses/refresh', () async {
      final client = _FakeBackendClient()
        ..nextPost = Success(
          HarnessListResponse(harnesses: <HarnessInfo>[claude]).toJson(),
        );
      final controller = StreamController<WsEnvelope>.broadcast();
      addTearDown(controller.close);

      final ds = HarnessesRemoteDataSourceImpl(
        client: client,
        wsMessages: controller.stream,
      );

      final result = await ds.refreshAll();
      expect(client.postPaths, <String>['/api/v1/harnesses/refresh']);
      expect(result.valueOrNull?.harnesses, <HarnessInfo>[claude]);
    });

    test(
      'refreshHarness requests POST /api/v1/harnesses/:id/refresh',
      () async {
        final client = _FakeBackendClient()
          ..nextPost = Success(claude.toJson());
        final controller = StreamController<WsEnvelope>.broadcast();
        addTearDown(controller.close);

        final ds = HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: controller.stream,
        );

        final result = await ds.refreshHarness(HarnessId.claudeCode);
        expect(client.postPaths, <String>[
          '/api/v1/harnesses/claude_code/refresh',
        ]);
        expect(result.valueOrNull, claude);
      },
    );

    test('returns BackendFailure on malformed response JSON', () async {
      final client = _FakeBackendClient()
        ..nextGet = const Success(<String, Object?>{'unexpected': true});
      final controller = StreamController<WsEnvelope>.broadcast();
      addTearDown(controller.close);

      final ds = HarnessesRemoteDataSourceImpl(
        client: client,
        wsMessages: controller.stream,
      );

      final result = await ds.getHarnesses();
      expect(result.failureOrNull, isA<BackendFailure>());
    });

    test(
      'watchHarnessUpdates filters WS messages and ignores malformed frames',
      () async {
        final client = _FakeBackendClient();
        final controller = StreamController<WsEnvelope>.broadcast();
        addTearDown(controller.close);

        final ds = HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: controller.stream,
        );

        final received = <HarnessInfo>[];
        final sub = ds.watchHarnessUpdates().listen(received.add);
        addTearDown(sub.cancel);

        controller
          ..add(const WsEnvelope(type: WsMessageType.serverHello, id: '1'))
          ..add(
            const WsEnvelope(
              type: WsMessageType.harnessStatusUpdated,
              id: '2',
              payload: <String, Object?>{'invalid': true},
            ),
          )
          ..add(
            WsEnvelope(
              type: WsMessageType.harnessStatusUpdated,
              id: '3',
              payload: HarnessStatusUpdatedPayload(harness: claude).toJson(),
            ),
          );

        await pumpEventQueue();
        expect(received, <HarnessInfo>[claude]);
      },
    );
  });

  group('HarnessRepositoryImpl', () {
    test('maps data source responses to domain results', () async {
      final client = _FakeBackendClient()
        ..nextGet = Success(
          HarnessListResponse(harnesses: <HarnessInfo>[claude]).toJson(),
        )
        ..nextPost = Success(claude.toJson());
      final controller = StreamController<WsEnvelope>.broadcast();
      addTearDown(controller.close);

      final repo = HarnessRepositoryImpl(
        HarnessesRemoteDataSourceImpl(
          client: client,
          wsMessages: controller.stream,
        ),
      );

      final listResult = await repo.getHarnesses();
      expect(listResult.valueOrNull, <HarnessInfo>[claude]);

      final oneResult = await repo.refreshHarness(HarnessId.claudeCode);
      expect(oneResult.valueOrNull, claude);
    });
  });
}
