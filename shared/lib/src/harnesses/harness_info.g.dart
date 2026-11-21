// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessInfo _$HarnessInfoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HarnessInfo', json, ($checkedConvert) {
      final val = _HarnessInfo(
        id: $checkedConvert('id', (v) => $enumDecode(_$HarnessIdEnumMap, v)),
        displayName: $checkedConvert('displayName', (v) => v as String),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$HarnessStatusEnumMap, v),
        ),
        checkedAt: $checkedConvert(
          'checkedAt',
          (v) => DateTime.parse(v as String),
        ),
        version: $checkedConvert('version', (v) => v as String?),
        executablePath: $checkedConvert('executablePath', (v) => v as String?),
        errorMessage: $checkedConvert('errorMessage', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$HarnessInfoToJson(_HarnessInfo instance) =>
    <String, dynamic>{
      'id': _$HarnessIdEnumMap[instance.id]!,
      'displayName': instance.displayName,
      'status': _$HarnessStatusEnumMap[instance.status]!,
      'checkedAt': instance.checkedAt.toIso8601String(),
      'version': ?instance.version,
      'executablePath': ?instance.executablePath,
      'errorMessage': ?instance.errorMessage,
    };

const _$HarnessIdEnumMap = {
  HarnessId.claudeCode: 'claude_code',
  HarnessId.codex: 'codex',
  HarnessId.geminiCli: 'gemini_cli',
  HarnessId.antigravity: 'antigravity',
};

const _$HarnessStatusEnumMap = {
  HarnessStatus.ready: 'ready',
  HarnessStatus.notInstalled: 'notInstalled',
  HarnessStatus.authError: 'authError',
  HarnessStatus.outdated: 'outdated',
  HarnessStatus.unavailable: 'unavailable',
};
