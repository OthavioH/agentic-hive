import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_remote_data_source.g.dart';

/// Remote data source for `/api/v1/settings` and `settings.updated` WebSocket
/// events.
abstract interface class SettingsRemoteDataSource {
  /// Calls `GET /api/v1/settings`.
  Future<Result<AppSettings>> getSettings();

  /// Calls `PUT /api/v1/settings`.
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request);

  /// Stream of [AppSettings] emitted by `settings.updated` WebSocket messages.
  Stream<AppSettings> watchSettingsUpdates();
}

/// Default [SettingsRemoteDataSource] backed by [BackendClient] and
/// [WsEnvelope] messages.
final class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  /// Creates a [SettingsRemoteDataSourceImpl].
  const new({required this._client, required this._wsMessages});

  static const String _settingsPath = '/api/v1/settings';

  final BackendClient _client;
  final Stream<WsEnvelope> _wsMessages;

  @override
  Future<Result<AppSettings>> getSettings() =>
      _decode(_client.sendJsonRequest('GET', _settingsPath));

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) =>
      _decode(
        _client.sendJsonRequest('PUT', _settingsPath, body: request.toJson()),
      );

  @override
  Stream<AppSettings> watchSettingsUpdates() => _wsMessages
      .where((envelope) => envelope.type == WsMessageType.settingsUpdated)
      .transform(
        StreamTransformer<WsEnvelope, AppSettings>.fromHandlers(
          handleData: (envelope, sink) {
            try {
              final payload = SettingsUpdatedPayload.fromJson(envelope.payload);
              sink.add(payload.settings);
            } on FormatException {
              // Ignore malformed update frames without breaking the stream.
            }
          },
        ),
      );

  Future<Result<AppSettings>> _decode(Future<Result<JsonMap>> request) async {
    final result = await request;
    return switch (result) {
      FailureResult<JsonMap>(:final failure) => FailureResult<AppSettings>(
        failure,
      ),
      Success<JsonMap>(:final value) => _parseSettings(value),
    };
  }

  Result<AppSettings> _parseSettings(JsonMap json) {
    try {
      return Success<AppSettings>(AppSettings.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult<AppSettings>(
        BackendFailure('Malformed settings payload: ${error.message}'),
      );
    }
  }
}

/// Provides the [SettingsRemoteDataSource] wired to [backendClientProvider]
/// and the active WebSocket session.
@riverpod
SettingsRemoteDataSource settingsRemoteDataSource(Ref ref) {
  final client = ref.watch(backendClientProvider);
  final session = ref.watch(backendWebSocketSessionProvider);
  return SettingsRemoteDataSourceImpl(
    client: client,
    wsMessages: session?.messages ?? const Stream<WsEnvelope>.empty(),
  );
}
