// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WsEnvelope _$WsEnvelopeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WsEnvelope', json, ($checkedConvert) {
      final val = _WsEnvelope(
        type: $checkedConvert('type', (v) => v as String),
        id: $checkedConvert('id', (v) => v as String),
        payload: $checkedConvert(
          'payload',
          (v) => v as Map<String, dynamic>? ?? const <String, Object?>{},
        ),
      );
      return val;
    });

Map<String, dynamic> _$WsEnvelopeToJson(_WsEnvelope instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'payload': instance.payload,
    };
