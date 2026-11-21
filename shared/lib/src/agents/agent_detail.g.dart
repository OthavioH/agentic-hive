// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentDetail _$AgentDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_AgentDetail', json, ($checkedConvert) {
      final val = _AgentDetail(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        contentHash: $checkedConvert('contentHash', (v) => v as String),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => DateTime.parse(v as String),
        ),
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
        parseError: $checkedConvert('parseError', (v) => v as String?),
        rawContent: $checkedConvert('rawContent', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$AgentDetailToJson(_AgentDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'contentHash': instance.contentHash,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'description': instance.description,
      'tags': instance.tags,
      'requiredSkills': instance.requiredSkills,
      'requiredTools': instance.requiredTools,
      'allowedTools': instance.allowedTools,
      'deniedTools': instance.deniedTools,
      'prompt': instance.prompt,
      'parseError': ?instance.parseError,
      'rawContent': ?instance.rawContent,
    };
