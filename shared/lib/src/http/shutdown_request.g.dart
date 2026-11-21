// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shutdown_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShutdownRequest _$ShutdownRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ShutdownRequest', json, ($checkedConvert) {
      final val = _ShutdownRequest(
        force: $checkedConvert('force', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ShutdownRequestToJson(_ShutdownRequest instance) =>
    <String, dynamic>{'force': instance.force};
