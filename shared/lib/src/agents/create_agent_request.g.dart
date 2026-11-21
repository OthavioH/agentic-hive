// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_agent_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateAgentRequest _$CreateAgentRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_CreateAgentRequest', json, ($checkedConvert) {
      final val = _CreateAgentRequest(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
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

Map<String, dynamic> _$CreateAgentRequestToJson(_CreateAgentRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'tags': instance.tags,
      'requiredSkills': instance.requiredSkills,
      'requiredTools': instance.requiredTools,
      'allowedTools': instance.allowedTools,
      'deniedTools': instance.deniedTools,
      'prompt': instance.prompt,
    };
