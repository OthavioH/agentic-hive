// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => _ServerInfo(
  pid: (json['pid'] as num).toInt(),
  version: json['version'] as String,
  socketPath: json['socketPath'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
);

Map<String, dynamic> _$ServerInfoToJson(_ServerInfo instance) =>
    <String, dynamic>{
      'pid': instance.pid,
      'version': instance.version,
      'socketPath': instance.socketPath,
      'startedAt': instance.startedAt.toIso8601String(),
    };
