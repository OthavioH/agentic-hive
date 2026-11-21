// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateWorkflowRequest _$CreateWorkflowRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_CreateWorkflowRequest', json, ($checkedConvert) {
  final val = _CreateWorkflowRequest(
    name: $checkedConvert('name', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
    nodes: $checkedConvert(
      'nodes',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkflowNode>[],
    ),
    edges: $checkedConvert(
      'edges',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkflowEdge>[],
    ),
    entryNodeId: $checkedConvert('entryNodeId', (v) => v as String?),
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateWorkflowRequestToJson(
  _CreateWorkflowRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': ?instance.description,
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'edges': instance.edges.map((e) => e.toJson()).toList(),
  'entryNodeId': ?instance.entryNodeId,
  'schemaVersion': instance.schemaVersion,
};

_UpdateWorkflowRequest _$UpdateWorkflowRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_UpdateWorkflowRequest', json, ($checkedConvert) {
  final val = _UpdateWorkflowRequest(
    name: $checkedConvert('name', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
    nodes: $checkedConvert(
      'nodes',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkflowNode>[],
    ),
    edges: $checkedConvert(
      'edges',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkflowEdge>[],
    ),
    entryNodeId: $checkedConvert('entryNodeId', (v) => v as String?),
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
  );
  return val;
});

Map<String, dynamic> _$UpdateWorkflowRequestToJson(
  _UpdateWorkflowRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': ?instance.description,
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'edges': instance.edges.map((e) => e.toJson()).toList(),
  'entryNodeId': ?instance.entryNodeId,
  'schemaVersion': instance.schemaVersion,
};

_DuplicateWorkflowRequest _$DuplicateWorkflowRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_DuplicateWorkflowRequest', json, ($checkedConvert) {
  final val = _DuplicateWorkflowRequest(
    name: $checkedConvert('name', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$DuplicateWorkflowRequestToJson(
  _DuplicateWorkflowRequest instance,
) => <String, dynamic>{'name': ?instance.name};

_ValidateWorkflowRequest _$ValidateWorkflowRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ValidateWorkflowRequest', json, ($checkedConvert) {
  final val = _ValidateWorkflowRequest(
    workflow: $checkedConvert(
      'workflow',
      (v) => Workflow.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ValidateWorkflowRequestToJson(
  _ValidateWorkflowRequest instance,
) => <String, dynamic>{'workflow': instance.workflow.toJson()};

_WorkflowListResponse _$WorkflowListResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_WorkflowListResponse', json, ($checkedConvert) {
  final val = _WorkflowListResponse(
    workflows: $checkedConvert(
      'workflows',
      (v) => (v as List<dynamic>)
          .map((e) => WorkflowSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$WorkflowListResponseToJson(
  _WorkflowListResponse instance,
) => <String, dynamic>{
  'workflows': instance.workflows.map((e) => e.toJson()).toList(),
};

_WorkflowResponse _$WorkflowResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_WorkflowResponse', json, ($checkedConvert) {
      final val = _WorkflowResponse(
        workflow: $checkedConvert(
          'workflow',
          (v) => Workflow.fromJson(v as Map<String, dynamic>),
        ),
        validation: $checkedConvert(
          'validation',
          (v) => WorkflowValidationResult.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$WorkflowResponseToJson(_WorkflowResponse instance) =>
    <String, dynamic>{
      'workflow': instance.workflow.toJson(),
      'validation': instance.validation.toJson(),
    };
