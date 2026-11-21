import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'harnesses_remote_data_source.g.dart';

/// Remote data source for harness endpoints and WebSocket status updates.
abstract interface class HarnessesRemoteDataSource {
  /// Calls `GET /api/v1/harnesses`.
  Future<Result<HarnessListResponse>> getHarnesses();

  /// Calls `POST /api/v1/harnesses/refresh`.
  Future<Result<HarnessListResponse>> refreshAll();

  /// Calls `POST /api/v1/harnesses/:id/refresh`.
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id);

  /// Stream of [HarnessInfo] updates parsed from `harness.status_updated`
  /// WebSocket messages.
  Stream<HarnessInfo> watchHarnessUpdates();
}

/// Default [HarnessesRemoteDataSource] backed by [BackendClient] and
/// [WsEnvelope] messages.
final class HarnessesRemoteDataSourceImpl implements HarnessesRemoteDataSource {
  /// Creates a [HarnessesRemoteDataSourceImpl].
  const new({required this._client, required this._wsMessages});

  final BackendClient _client;
  final Stream<WsEnvelope> _wsMessages;

  @override
  Future<Result<HarnessListResponse>> getHarnesses() => _decodeJsonResult(
    _client.getJson('/api/v1/harnesses'),
    HarnessListResponse.fromJson,
  );

  @override
  Future<Result<HarnessListResponse>> refreshAll() => _decodeJsonResult(
    _client.postJson('/api/v1/harnesses/refresh'),
    HarnessListResponse.fromJson,
  );

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) => _decodeJsonResult(
    _client.postJson('/api/v1/harnesses/${id.wireName}/refresh'),
    HarnessInfo.fromJson,
  );

  @override
  Stream<HarnessInfo> watchHarnessUpdates() => _wsMessages
      .where((envelope) => envelope.type == WsMessageType.harnessStatusUpdated)
      .transform(
        StreamTransformer<WsEnvelope, HarnessInfo>.fromHandlers(
          handleData: (envelope, sink) {
            try {
              final payload = HarnessStatusUpdatedPayload.fromJson(
                envelope.payload,
              );
              sink.add(payload.harness);
            } on FormatException {
              // Ignore malformed update frames without breaking the stream.
            }
          },
        ),
      );

  Future<Result<T>> _decodeJsonResult<T>(
    Future<Result<JsonMap>> request,
    T Function(JsonMap json) fromJson,
  ) async {
    final result = await request;
    return switch (result) {
      FailureResult<JsonMap>(:final failure) => FailureResult<T>(failure),
      Success<JsonMap>(:final value) => _parse(value, fromJson),
    };
  }

  Result<T> _parse<T>(JsonMap json, T Function(JsonMap json) fromJson) {
    try {
      return Success<T>(fromJson(json));
    } on FormatException catch (error) {
      return FailureResult<T>(
        BackendFailure('Malformed harness payload: ${error.message}'),
      );
    }
  }
}

/// Provides the [HarnessesRemoteDataSource] wired to [backendClientProvider]
/// and the active WebSocket session.
@riverpod
HarnessesRemoteDataSource harnessesRemoteDataSource(Ref ref) {
  final client = ref.watch(backendClientProvider);
  final session = ref.watch(backendWebSocketSessionProvider);
  return HarnessesRemoteDataSourceImpl(
    client: client,
    wsMessages: session?.messages ?? const Stream<WsEnvelope>.empty(),
  );
}
