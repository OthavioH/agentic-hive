// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StatusResponse _$StatusResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_StatusResponse', json, ($checkedConvert) {
      final val = _StatusResponse(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$BackendStatusEnumMap, v),
        ),
        version: $checkedConvert('version', (v) => v as String),
        uptimeSeconds: $checkedConvert(
          'uptimeSeconds',
          (v) => (v as num).toInt(),
        ),
        dataDir: $checkedConvert('dataDir', (v) => v as String),
        database: $checkedConvert(
          'database',
          (v) => DatabaseStatus.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$StatusResponseToJson(_StatusResponse instance) =>
    <String, dynamic>{
      'status': _$BackendStatusEnumMap[instance.status]!,
      'version': instance.version,
      'uptimeSeconds': instance.uptimeSeconds,
      'dataDir': instance.dataDir,
      'database': instance.database.toJson(),
    };

const _$BackendStatusEnumMap = {
  BackendStatus.ok: 'ok',
  BackendStatus.degraded: 'degraded',
};

_DatabaseStatus _$DatabaseStatusFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_DatabaseStatus', json, ($checkedConvert) {
      final val = _DatabaseStatus(
        ok: $checkedConvert('status', (v) => _dbStatusFromJson(v as String)),
        schemaVersion: $checkedConvert(
          'schemaVersion',
          (v) => (v as num?)?.toInt(),
        ),
        error: $checkedConvert('error', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'ok': 'status'});

Map<String, dynamic> _$DatabaseStatusToJson(_DatabaseStatus instance) =>
    <String, dynamic>{
      'status': _dbStatusToJson(instance.ok),
      'schemaVersion': ?instance.schemaVersion,
      'error': ?instance.error,
    };
