// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RunSummary _$RunSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_RunSummary', json, ($checkedConvert) {
      final val = _RunSummary(
        id: $checkedConvert('id', (v) => v as String),
        workflowName: $checkedConvert('workflowName', (v) => v as String),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$RunStatusEnumMap, v),
        ),
        startedAt: $checkedConvert(
          'startedAt',
          (v) => DateTime.parse(v as String),
        ),
        checkpointCount: $checkedConvert(
          'checkpointCount',
          (v) => (v as num).toInt(),
        ),
        workflowId: $checkedConvert('workflowId', (v) => v as String?),
        finishedAt: $checkedConvert(
          'finishedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RunSummaryToJson(_RunSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workflowName': instance.workflowName,
      'status': _$RunStatusEnumMap[instance.status]!,
      'startedAt': instance.startedAt.toIso8601String(),
      'checkpointCount': instance.checkpointCount,
      'workflowId': ?instance.workflowId,
      'finishedAt': ?instance.finishedAt?.toIso8601String(),
    };

const _$RunStatusEnumMap = {
  RunStatus.running: 'running',
  RunStatus.paused: 'paused',
  RunStatus.interrupted: 'interrupted',
  RunStatus.succeeded: 'succeeded',
  RunStatus.failed: 'failed',
  RunStatus.cancelled: 'cancelled',
};
