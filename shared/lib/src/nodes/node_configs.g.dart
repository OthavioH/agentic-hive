// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_configs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessNodeConfig _$HarnessNodeConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HarnessNodeConfig', json, ($checkedConvert) {
      final val = _HarnessNodeConfig(
        agentId: $checkedConvert('agentId', (v) => v as String?),
        additionalInstructions: $checkedConvert(
          'additionalInstructions',
          (v) => v as String?,
        ),
        workingDirectory: $checkedConvert(
          'workingDirectory',
          (v) => v as String?,
        ),
        timeoutSeconds: $checkedConvert(
          'timeoutSeconds',
          (v) => (v as num?)?.toInt(),
        ),
        extraArgs: $checkedConvert(
          'extraArgs',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
      );
      return val;
    });

Map<String, dynamic> _$HarnessNodeConfigToJson(_HarnessNodeConfig instance) =>
    <String, dynamic>{
      'agentId': ?instance.agentId,
      'additionalInstructions': ?instance.additionalInstructions,
      'workingDirectory': ?instance.workingDirectory,
      'timeoutSeconds': ?instance.timeoutSeconds,
      'extraArgs': instance.extraArgs,
    };

_TerminalHarnessNodeConfig _$TerminalHarnessNodeConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_TerminalHarnessNodeConfig', json, ($checkedConvert) {
  final val = _TerminalHarnessNodeConfig(
    agentId: $checkedConvert('agentId', (v) => v as String?),
    additionalInstructions: $checkedConvert(
      'additionalInstructions',
      (v) => v as String?,
    ),
    workingDirectory: $checkedConvert('workingDirectory', (v) => v as String?),
    timeoutSeconds: $checkedConvert(
      'timeoutSeconds',
      (v) => (v as num?)?.toInt(),
    ),
    extraArgs: $checkedConvert(
      'extraArgs',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
    ),
    command: $checkedConvert('command', (v) => v as String?),
    args: $checkedConvert(
      'args',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
    ),
  );
  return val;
});

Map<String, dynamic> _$TerminalHarnessNodeConfigToJson(
  _TerminalHarnessNodeConfig instance,
) => <String, dynamic>{
  'agentId': ?instance.agentId,
  'additionalInstructions': ?instance.additionalInstructions,
  'workingDirectory': ?instance.workingDirectory,
  'timeoutSeconds': ?instance.timeoutSeconds,
  'extraArgs': instance.extraArgs,
  'command': ?instance.command,
  'args': instance.args,
};

_CommandNodeConfig _$CommandNodeConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_CommandNodeConfig', json, ($checkedConvert) {
      final val = _CommandNodeConfig(
        command: $checkedConvert('command', (v) => v as String),
        args: $checkedConvert(
          'args',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        workingDirectory: $checkedConvert(
          'workingDirectory',
          (v) => v as String?,
        ),
        timeoutSeconds: $checkedConvert(
          'timeoutSeconds',
          (v) => (v as num?)?.toInt(),
        ),
        env: $checkedConvert(
          'env',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              const <String, String>{},
        ),
      );
      return val;
    });

Map<String, dynamic> _$CommandNodeConfigToJson(_CommandNodeConfig instance) =>
    <String, dynamic>{
      'command': instance.command,
      'args': instance.args,
      'workingDirectory': ?instance.workingDirectory,
      'timeoutSeconds': ?instance.timeoutSeconds,
      'env': instance.env,
    };

_TestsValidatorNodeConfig _$TestsValidatorNodeConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_TestsValidatorNodeConfig', json, ($checkedConvert) {
  final val = _TestsValidatorNodeConfig(
    command: $checkedConvert('command', (v) => v as String),
    args: $checkedConvert(
      'args',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
    ),
    workingDirectory: $checkedConvert('workingDirectory', (v) => v as String?),
    timeoutSeconds: $checkedConvert(
      'timeoutSeconds',
      (v) => (v as num?)?.toInt(),
    ),
  );
  return val;
});

Map<String, dynamic> _$TestsValidatorNodeConfigToJson(
  _TestsValidatorNodeConfig instance,
) => <String, dynamic>{
  'command': instance.command,
  'args': instance.args,
  'workingDirectory': ?instance.workingDirectory,
  'timeoutSeconds': ?instance.timeoutSeconds,
};

_ChecklistRule _$ChecklistRuleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ChecklistRule', json, ($checkedConvert) {
      final val = _ChecklistRule(
        label: $checkedConvert('label', (v) => v as String),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(_$ChecklistRuleKindEnumMap, v),
        ),
        path: $checkedConvert('path', (v) => v as String?),
        command: $checkedConvert('command', (v) => v as String?),
        workingDirectory: $checkedConvert(
          'workingDirectory',
          (v) => v as String?,
        ),
        pattern: $checkedConvert('pattern', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ChecklistRuleToJson(_ChecklistRule instance) =>
    <String, dynamic>{
      'label': instance.label,
      'kind': _$ChecklistRuleKindEnumMap[instance.kind]!,
      'path': ?instance.path,
      'command': ?instance.command,
      'workingDirectory': ?instance.workingDirectory,
      'pattern': ?instance.pattern,
    };

const _$ChecklistRuleKindEnumMap = {
  ChecklistRuleKind.fileExists: 'fileExists',
  ChecklistRuleKind.commandSucceeds: 'commandSucceeds',
  ChecklistRuleKind.outputMatchesRegex: 'outputMatchesRegex',
};

_ChecklistValidatorNodeConfig _$ChecklistValidatorNodeConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ChecklistValidatorNodeConfig', json, ($checkedConvert) {
  final val = _ChecklistValidatorNodeConfig(
    rules: $checkedConvert(
      'rules',
      (v) => (v as List<dynamic>)
          .map((e) => ChecklistRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$ChecklistValidatorNodeConfigToJson(
  _ChecklistValidatorNodeConfig instance,
) => <String, dynamic>{'rules': instance.rules.map((e) => e.toJson()).toList()};

_ReviewValidatorNodeConfig _$ReviewValidatorNodeConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ReviewValidatorNodeConfig', json, ($checkedConvert) {
  final val = _ReviewValidatorNodeConfig(
    harnessType: $checkedConvert('harnessType', (v) => v as String),
    agentId: $checkedConvert('agentId', (v) => v as String?),
    reviewCriteria: $checkedConvert('reviewCriteria', (v) => v as String?),
    timeoutSeconds: $checkedConvert(
      'timeoutSeconds',
      (v) => (v as num?)?.toInt(),
    ),
  );
  return val;
});

Map<String, dynamic> _$ReviewValidatorNodeConfigToJson(
  _ReviewValidatorNodeConfig instance,
) => <String, dynamic>{
  'harnessType': instance.harnessType,
  'agentId': ?instance.agentId,
  'reviewCriteria': ?instance.reviewCriteria,
  'timeoutSeconds': ?instance.timeoutSeconds,
};

_HumanApprovalNodeConfig _$HumanApprovalNodeConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_HumanApprovalNodeConfig', json, ($checkedConvert) {
  final val = _HumanApprovalNodeConfig(
    instructions: $checkedConvert('instructions', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String?),
    allowFeedback: $checkedConvert('allowFeedback', (v) => v as bool? ?? true),
  );
  return val;
});

Map<String, dynamic> _$HumanApprovalNodeConfigToJson(
  _HumanApprovalNodeConfig instance,
) => <String, dynamic>{
  'instructions': instance.instructions,
  'title': ?instance.title,
  'allowFeedback': instance.allowFeedback,
};
