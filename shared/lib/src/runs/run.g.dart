// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Run _$RunFromJson(Map<String, dynamic> json) => $checkedCreate('_Run', json, (
  $checkedConvert,
) {
  final val = _Run(
    id: $checkedConvert('id', (v) => v as String),
    workflowName: $checkedConvert('workflowName', (v) => v as String),
    workflowDefinition: $checkedConvert(
      'workflowDefinition',
      (v) => Workflow.fromJson(v as Map<String, dynamic>),
    ),
    workspacePath: $checkedConvert('workspacePath', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$RunStatusEnumMap, v),
    ),
    startedAt: $checkedConvert('startedAt', (v) => DateTime.parse(v as String)),
    workflowId: $checkedConvert('workflowId', (v) => v as String?),
    finishedAt: $checkedConvert(
      'finishedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    errorMessage: $checkedConvert('errorMessage', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$RunToJson(_Run instance) => <String, dynamic>{
  'id': instance.id,
  'workflowName': instance.workflowName,
  'workflowDefinition': instance.workflowDefinition.toJson(),
  'workspacePath': instance.workspacePath,
  'status': _$RunStatusEnumMap[instance.status]!,
  'startedAt': instance.startedAt.toIso8601String(),
  'workflowId': ?instance.workflowId,
  'finishedAt': ?instance.finishedAt?.toIso8601String(),
  'errorMessage': ?instance.errorMessage,
};

const _$RunStatusEnumMap = {
  RunStatus.running: 'running',
  RunStatus.paused: 'paused',
  RunStatus.interrupted: 'interrupted',
  RunStatus.succeeded: 'succeeded',
  RunStatus.failed: 'failed',
  RunStatus.cancelled: 'cancelled',
};
