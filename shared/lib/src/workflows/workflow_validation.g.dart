// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_validation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowValidationIssue _$WorkflowValidationIssueFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_WorkflowValidationIssue', json, ($checkedConvert) {
  final val = _WorkflowValidationIssue(
    severity: $checkedConvert(
      'severity',
      (v) => $enumDecode(_$WorkflowValidationSeverityEnumMap, v),
    ),
    code: $checkedConvert('code', (v) => v as String),
    message: $checkedConvert('message', (v) => v as String),
    nodeId: $checkedConvert('nodeId', (v) => v as String?),
    edgeId: $checkedConvert('edgeId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$WorkflowValidationIssueToJson(
  _WorkflowValidationIssue instance,
) => <String, dynamic>{
  'severity': _$WorkflowValidationSeverityEnumMap[instance.severity]!,
  'code': instance.code,
  'message': instance.message,
  'nodeId': ?instance.nodeId,
  'edgeId': ?instance.edgeId,
};

const _$WorkflowValidationSeverityEnumMap = {
  WorkflowValidationSeverity.error: 'error',
  WorkflowValidationSeverity.warning: 'warning',
};

_WorkflowValidationResult _$WorkflowValidationResultFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_WorkflowValidationResult', json, ($checkedConvert) {
  final val = _WorkflowValidationResult(
    isValid: $checkedConvert('isValid', (v) => v as bool),
    issues: $checkedConvert(
      'issues',
      (v) =>
          (v as List<dynamic>?)
              ?.map(
                (e) =>
                    WorkflowValidationIssue.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <WorkflowValidationIssue>[],
    ),
  );
  return val;
});

Map<String, dynamic> _$WorkflowValidationResultToJson(
  _WorkflowValidationResult instance,
) => <String, dynamic>{
  'isValid': instance.isValid,
  'issues': instance.issues.map((e) => e.toJson()).toList(),
};
