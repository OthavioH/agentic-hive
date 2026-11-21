import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_repository_impl.dart';
import 'package:agentic_hive_frontend/data/pauses/pauses_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Future<Result<JsonMap>> Function(String path)? onGetJson;

  final List<String> requestedPaths = <String>[];

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async {
    requestedPaths.add(path);
    final handler = onGetJson;
    if (handler != null) {
      return await handler(path);
    }
    return const Success(<String, Object?>{'items': <Object?>[], 'total': 0});
  }

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const FailureResult(NetworkFailure('unused'));

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
  Future<Result<void>> delete(String path) async =>
      const FailureResult(NetworkFailure('unused'));

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
  Pause makePause(int index) => Pause(
    id: 'pause-$index',
    runId: 'run-$index',
    nodeId: 'node-$index',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Workflow $index',
    nodeLabel: 'Gate $index',
    createdAt: DateTime.utc(2026, 11, 21, 10, index % 60),
  );

  test(
    'PausesRemoteDataSource pages through all pending pauses when total > 50',
    () async {
      final client = _FakeBackendClient();
      final all = <Pause>[for (var i = 0; i < 65; i++) makePause(i)];

      client.onGetJson = (path) async {
        final uri = Uri.parse(path);
        final limit = int.parse(uri.queryParameters['limit']!);
        final offset = int.parse(uri.queryParameters['offset']!);
        final slice = all.skip(offset).take(limit).toList();
        return Success(
          PausesListResponse(items: slice, total: all.length).toJson(),
        );
      };

      final dataSource = PausesRemoteDataSource(client);
      final result = await dataSource.listPendingPauses();

      expect(result, isA<Success<List<Pause>>>());
      final items = (result as Success<List<Pause>>).value;
      expect(items, hasLength(65));
      expect(client.requestedPaths, <String>[
        '/api/v1/pauses?status=pending&limit=50&offset=0',
        '/api/v1/pauses?status=pending&limit=50&offset=50',
      ]);
    },
  );

  test('preserves pause.created arriving during in-flight fetch', () async {
    final client = _FakeBackendClient();
    final fetchCompleter = Completer<Result<JsonMap>>();
    client.onGetJson = (_) => fetchCompleter.future;

    final events = StreamController<PauseEvent>.broadcast();
    final repo = PauseRepositoryImpl(
      remoteDataSource: PausesRemoteDataSource(client),
      eventsStream: events.stream,
    );
    addTearDown(() async {
      await repo.dispose();
      await events.close();
    });

    final counts = <int>[];
    final sub = repo.watchPendingPausesCount().listen(counts.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);

    final listFuture = repo.listPendingPauses();

    final inFlightPause = makePause(99);
    events.add(PauseCreatedEvent(inFlightPause));
    await Future<void>.delayed(Duration.zero);
    expect(counts.last, 1);

    fetchCompleter.complete(
      Success(
        PausesListResponse(items: <Pause>[makePause(1)], total: 1).toJson(),
      ),
    );

    final result = await listFuture;
    await Future<void>.delayed(Duration.zero);

    final items = (result as Success<List<Pause>>).value;
    expect(
      items.map((p) => p.id),
      containsAll(<String>['pause-1', 'pause-99']),
    );
    expect(counts.last, 2);
  });
}
