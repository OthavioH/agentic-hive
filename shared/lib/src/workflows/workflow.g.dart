// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Workflow _$WorkflowFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_Workflow', json, ($checkedConvert) {
  final val = _Workflow(
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    nodes: $checkedConvert(
      'nodes',
      (v) => (v as List<dynamic>)
          .map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    edges: $checkedConvert(
      'edges',
      (v) => (v as List<dynamic>)
          .map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
    description: $checkedConvert('description', (v) => v as String?),
    entryNodeId: $checkedConvert('entryNodeId', (v) => v as String?),
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
  );
  return val;
});

Map<String, dynamic> _$WorkflowToJson(_Workflow instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'edges': instance.edges.map((e) => e.toJson()).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'description': ?instance.description,
  'entryNodeId': ?instance.entryNodeId,
  'schemaVersion': instance.schemaVersion,
};
