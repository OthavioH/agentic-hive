import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

/// Metadata written to `server.json` by the running backend.
@freezed
sealed class ServerInfo with _$ServerInfo {
  /// Creates a [ServerInfo] record.
  const factory({
    required int pid,
    required String version,
    required String socketPath,
    required DateTime startedAt,
  }) = _ServerInfo;

  /// Decodes a [ServerInfo] JSON map.
  factory fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);
}
