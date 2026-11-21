// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RunEvent _$RunEventFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_RunEvent', json, ($checkedConvert) {
  final val = _RunEvent(
    id: $checkedConvert('id', (v) => v as String),
    runId: $checkedConvert('runId', (v) => v as String),
    sequence: $checkedConvert('sequence', (v) => (v as num).toInt()),
    type: $checkedConvert('type', (v) => $enumDecode(_$RunEventTypeEnumMap, v)),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    nodeId: $checkedConvert('nodeId', (v) => v as String?),
    edgeId: $checkedConvert('edgeId', (v) => v as String?),
    payload: $checkedConvert(
      'payload',
      (v) => v as Map<String, dynamic>? ?? const <String, Object?>{},
    ),
  );
  return val;
});

Map<String, dynamic> _$RunEventToJson(_RunEvent instance) => <String, dynamic>{
  'id': instance.id,
  'runId': instance.runId,
  'sequence': instance.sequence,
  'type': _$RunEventTypeEnumMap[instance.type]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'nodeId': ?instance.nodeId,
  'edgeId': ?instance.edgeId,
  'payload': instance.payload,
};

const _$RunEventTypeEnumMap = {
  RunEventType.runStarted: 'run.started',
  RunEventType.runPaused: 'run.paused',
  RunEventType.runResumed: 'run.resumed',
  RunEventType.runInterrupted: 'run.interrupted',
  RunEventType.runSucceeded: 'run.succeeded',
  RunEventType.runFailed: 'run.failed',
  RunEventType.runCancelled: 'run.cancelled',
  RunEventType.nodeStarted: 'node.started',
  RunEventType.nodeCompleted: 'node.completed',
  RunEventType.nodeFailed: 'node.failed',
  RunEventType.nodeRetried: 'node.retried',
  RunEventType.checkpointSaved: 'checkpoint.saved',
};
