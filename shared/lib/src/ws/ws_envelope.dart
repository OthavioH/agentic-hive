import 'dart:convert';

import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ws_envelope.freezed.dart';
part 'ws_envelope.g.dart';

/// The frame every WebSocket message travels in:
/// `{"type": "...", "id": "...", "payload": {...}}`.
@freezed
sealed class WsEnvelope with _$WsEnvelope {
  /// Creates an envelope.
  const factory({
    required String type,
    required String id,
    @Default(<String, Object?>{}) JsonMap payload,
  }) = _WsEnvelope;

  const new _();

  /// Decodes an envelope; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WsEnvelopeFromJson);

  /// Decodes a text frame. Throws a [FormatException] for anything that is
  /// not a valid envelope.
  factory decode(String frame) {
    final decoded = jsonDecode(frame);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A message must be a JSON object.');
    }
    return WsEnvelope.fromJson(decoded);
  }

  /// Encodes this envelope as a text frame.
  String encode() => jsonEncode(toJson());
}
