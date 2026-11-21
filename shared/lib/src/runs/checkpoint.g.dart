// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkpoint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Checkpoint _$CheckpointFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_Checkpoint', json, ($checkedConvert) {
  final val = _Checkpoint(
    id: $checkedConvert('id', (v) => v as String),
    runId: $checkedConvert('runId', (v) => v as String),
    sequence: $checkedConvert('sequence', (v) => (v as num).toInt()),
    pendingNodeIds: $checkedConvert(
      'pendingNodeIds',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    attemptsByEdge: $checkedConvert(
      'attemptsByEdge',
      (v) => Map<String, int>.from(v as Map),
    ),
    circuitBreakerCount: $checkedConvert(
      'circuitBreakerCount',
      (v) => (v as num).toInt(),
    ),
    nodeOutputs: $checkedConvert(
      'nodeOutputs',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, e as Map<String, dynamic>),
      ),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    completedNodeId: $checkedConvert('completedNodeId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CheckpointToJson(_Checkpoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'runId': instance.runId,
      'sequence': instance.sequence,
      'pendingNodeIds': instance.pendingNodeIds,
      'attemptsByEdge': instance.attemptsByEdge,
      'circuitBreakerCount': instance.circuitBreakerCount,
      'nodeOutputs': instance.nodeOutputs,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedNodeId': ?instance.completedNodeId,
    };
