// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowNode _$WorkflowNodeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WorkflowNode', json, ($checkedConvert) {
      final val = _WorkflowNode(
        id: $checkedConvert('id', (v) => v as String),
        type: $checkedConvert('type', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
        position: $checkedConvert(
          'position',
          (v) => WorkflowPosition.fromJson(v as Map<String, dynamic>),
        ),
        config: $checkedConvert(
          'config',
          (v) => v as Map<String, dynamic>? ?? const <String, Object?>{},
        ),
      );
      return val;
    });

Map<String, dynamic> _$WorkflowNodeToJson(_WorkflowNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'label': instance.label,
      'position': instance.position.toJson(),
      'config': instance.config,
    };
