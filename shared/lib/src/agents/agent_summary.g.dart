// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentSummary _$AgentSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_AgentSummary', json, ($checkedConvert) {
      final val = _AgentSummary(
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
        parseError: $checkedConvert('parseError', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$AgentSummaryToJson(_AgentSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'contentHash': instance.contentHash,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'description': instance.description,
      'tags': instance.tags,
      'parseError': ?instance.parseError,
    };
