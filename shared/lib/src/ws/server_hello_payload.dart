import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_hello_payload.freezed.dart';
part 'server_hello_payload.g.dart';

/// Payload of a `server.hello` message.
@freezed
sealed class ServerHelloPayload with _$ServerHelloPayload {
  /// Creates a hello payload.
  const factory({required String serverVersion, required int protocolVersion}) =
      _ServerHelloPayload;

  /// Decodes a hello payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ServerHelloPayloadFromJson);
}
