// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_hello_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerHelloPayload _$ServerHelloPayloadFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ServerHelloPayload', json, ($checkedConvert) {
      final val = _ServerHelloPayload(
        serverVersion: $checkedConvert('serverVersion', (v) => v as String),
        protocolVersion: $checkedConvert(
          'protocolVersion',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ServerHelloPayloadToJson(_ServerHelloPayload instance) =>
    <String, dynamic>{
      'serverVersion': instance.serverVersion,
      'protocolVersion': instance.protocolVersion,
    };
