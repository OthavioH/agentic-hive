// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_agent_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UpdateAgentRequest _$UpdateAgentRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_UpdateAgentRequest', json, ($checkedConvert) {
      final val = _UpdateAgentRequest(
        name: $checkedConvert('name', (v) => v as String),
        expectedHash: $checkedConvert('expectedHash', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String? ?? ''),
        tags: $checkedConvert(
          'tags',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        requiredSkills: $checkedConvert(
          'requiredSkills',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        requiredTools: $checkedConvert(
          'requiredTools',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        allowedTools: $checkedConvert(
          'allowedTools',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        deniedTools: $checkedConvert(
          'deniedTools',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
        ),
        prompt: $checkedConvert('prompt', (v) => v as String? ?? ''),
      );
      return val;
    });

Map<String, dynamic> _$UpdateAgentRequestToJson(_UpdateAgentRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'expectedHash': instance.expectedHash,
      'description': instance.description,
      'tags': instance.tags,
      'requiredSkills': instance.requiredSkills,
      'requiredTools': instance.requiredTools,
      'allowedTools': instance.allowedTools,
      'deniedTools': instance.deniedTools,
      'prompt': instance.prompt,
    };
