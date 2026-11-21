// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_edge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowEdge _$WorkflowEdgeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WorkflowEdge', json, ($checkedConvert) {
      final val = _WorkflowEdge(
        id: $checkedConvert('id', (v) => v as String),
        sourceNodeId: $checkedConvert('sourceNodeId', (v) => v as String),
        sourceOutput: $checkedConvert('sourceOutput', (v) => v as String),
        targetNodeId: $checkedConvert('targetNodeId', (v) => v as String),
        maxRetries: $checkedConvert('maxRetries', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$WorkflowEdgeToJson(_WorkflowEdge instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceNodeId': instance.sourceNodeId,
      'sourceOutput': instance.sourceOutput,
      'targetNodeId': instance.targetNodeId,
      'maxRetries': ?instance.maxRetries,
    };
