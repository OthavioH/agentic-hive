import 'package:agentic_hive_shared/src/harnesses/harness_id.dart';
import 'package:agentic_hive_shared/src/harnesses/harness_mcp_status.dart';
import 'package:agentic_hive_shared/src/harnesses/harness_status.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'harness_info.freezed.dart';
part 'harness_info.g.dart';

/// Detected state of a single CLI harness.
@freezed
sealed class HarnessInfo with _$HarnessInfo {
  /// Creates a harness info record.
  const factory({
    required HarnessId id,
    required String displayName,
    required HarnessStatus status,
    required DateTime checkedAt,
    String? version,
    String? executablePath,
    String? errorMessage,
    @Default(HarnessMcpStatus.unknown) HarnessMcpStatus mcpStatus,
    String? mcpMessage,
  }) = _HarnessInfo;

  /// Decodes a harness info record; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$HarnessInfoFromJson);
}
