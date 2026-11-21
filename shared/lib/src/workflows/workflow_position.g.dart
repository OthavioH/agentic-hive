// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowPosition _$WorkflowPositionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WorkflowPosition', json, ($checkedConvert) {
      final val = _WorkflowPosition(
        x: $checkedConvert('x', (v) => (v as num).toDouble()),
        y: $checkedConvert('y', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$WorkflowPositionToJson(_WorkflowPosition instance) =>
    <String, dynamic>{'x': instance.x, 'y': instance.y};
