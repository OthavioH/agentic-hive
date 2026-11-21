// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowSummary _$WorkflowSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WorkflowSummary', json, ($checkedConvert) {
      final val = _WorkflowSummary(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        nodeCount: $checkedConvert('nodeCount', (v) => (v as num).toInt()),
        edgeCount: $checkedConvert('edgeCount', (v) => (v as num).toInt()),
        hasValidationErrors: $checkedConvert(
          'hasValidationErrors',
          (v) => v as bool,
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => DateTime.parse(v as String),
        ),
        description: $checkedConvert('description', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$WorkflowSummaryToJson(_WorkflowSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nodeCount': instance.nodeCount,
      'edgeCount': instance.edgeCount,
      'hasValidationErrors': instance.hasValidationErrors,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'description': ?instance.description,
    };
