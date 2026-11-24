import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skill_notice_remote_data_source.g.dart';

/// Remote data source for automatic skill install notice endpoints and live
/// WebSocket updates.
abstract interface class SkillNoticeRemoteDataSource {
  /// Calls `GET /api/v1/skills/auto-install/notice`.
  Future<Result<SkillAutoInstallNotice?>> getPendingNotice();

  /// Calls `DELETE /api/v1/skills/auto-install/notice`.
  Future<Result<void>> dismissNotice();

  /// Stream of [SkillAutoInstallNotice] updates parsed from
  /// `skills.auto_installed` WebSocket messages.
  Stream<SkillAutoInstallNotice> watchNotices();
}

/// Default [SkillNoticeRemoteDataSource] backed by [BackendClient] and
/// [WsEnvelope] messages.
final class SkillNoticeRemoteDataSourceImpl
    implements SkillNoticeRemoteDataSource {
  /// Creates a [SkillNoticeRemoteDataSourceImpl].
  const new({required this._client, required this._wsMessages});

  static const String _noticePath = '/api/v1/skills/auto-install/notice';

  final BackendClient _client;
  final Stream<WsEnvelope> _wsMessages;

  @override
  Future<Result<SkillAutoInstallNotice?>> getPendingNotice() async {
    final result = await _client.getJson(_noticePath);
    return switch (result) {
      FailureResult<JsonMap>(:final failure) =>
        FailureResult<SkillAutoInstallNotice?>(failure),
      Success<JsonMap>(:final value) => _parseNoticeResponse(value),
    };
  }

  @override
  Future<Result<void>> dismissNotice() => _client.delete(_noticePath);

  @override
  Stream<SkillAutoInstallNotice> watchNotices() => _wsMessages
      .where((envelope) => envelope.type == WsMessageType.skillsAutoInstalled)
      .transform(
        StreamTransformer<WsEnvelope, SkillAutoInstallNotice>.fromHandlers(
          handleData: (envelope, sink) {
            try {
              final payload = SkillAutoInstallNoticePayload.fromJson(
                envelope.payload,
              );
              sink.add(payload.notice);
            } on FormatException {
              // Ignore malformed notice frames without breaking the stream.
            }
          },
        ),
      );

  Result<SkillAutoInstallNotice?> _parseNoticeResponse(JsonMap json) {
    try {
      return Success<SkillAutoInstallNotice?>(
        SkillAutoInstallNoticeResponse.fromJson(json).notice,
      );
    } on FormatException catch (error) {
      return FailureResult<SkillAutoInstallNotice?>(
        BackendFailure('Malformed skill notice payload: ${error.message}'),
      );
    }
  }
}

/// Provides the [SkillNoticeRemoteDataSource] wired to [backendClientProvider]
/// and the active WebSocket session.
@riverpod
SkillNoticeRemoteDataSource skillNoticeRemoteDataSource(Ref ref) {
  final client = ref.watch(backendClientProvider);
  final session = ref.watch(backendWebSocketSessionProvider);
  return SkillNoticeRemoteDataSourceImpl(
    client: client,
    wsMessages: session?.messages ?? const Stream<WsEnvelope>.empty(),
  );
}
