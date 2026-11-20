import 'dart:convert';

import 'package:agentic_hive_shared/src/json_fields.dart';

/// The frame every WebSocket message travels in:
/// `{"type": "...", "id": "...", "payload": {...}}`.
final class WsEnvelope {
  /// Creates an envelope.
  const new({required this.type, required this.id, this.payload = const {}});

  /// Decodes an envelope; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => WsEnvelope(
    type: readField<String>(json, 'type'),
    id: readField<String>(json, 'id'),
    payload: json['payload'] == null ? const {} : readObject(json, 'payload'),
  );

  /// Decodes a text frame. Throws a [FormatException] for anything that is
  /// not a valid envelope.
  factory decode(String frame) {
    final decoded = jsonDecode(frame);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A message must be a JSON object.');
    }
    return WsEnvelope.fromJson(decoded);
  }

  /// One of the values in `WsMessageType`.
  final String type;

  /// Unique id of this message, used by replies to point back at it.
  final String id;

  /// Message body; its shape depends on [type].
  final JsonMap payload;

  /// Encodes this envelope as JSON.
  JsonMap toJson() => {'type': type, 'id': id, 'payload': payload};

  /// Encodes this envelope as a text frame.
  String encode() => jsonEncode(toJson());
}
