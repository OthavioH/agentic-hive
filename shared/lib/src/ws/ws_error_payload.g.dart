// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_error_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WsErrorPayload _$WsErrorPayloadFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WsErrorPayload', json, ($checkedConvert) {
      final val = _WsErrorPayload(
        code: $checkedConvert('code', (v) => v as String),
        message: $checkedConvert('message', (v) => v as String),
        replyTo: $checkedConvert('replyTo', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$WsErrorPayloadToJson(_WsErrorPayload instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'replyTo': ?instance.replyTo,
    };
