// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shutdown_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShutdownResponse _$ShutdownResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ShutdownResponse', json, ($checkedConvert) {
      final val = _ShutdownResponse(
        status: $checkedConvert(
          'status',
          (v) => v as String? ?? 'shutting_down',
        ),
      );
      return val;
    });

Map<String, dynamic> _$ShutdownResponseToJson(_ShutdownResponse instance) =>
    <String, dynamic>{'status': instance.status};
