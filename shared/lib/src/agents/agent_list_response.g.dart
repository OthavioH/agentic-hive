// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentListResponse _$AgentListResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_AgentListResponse', json, ($checkedConvert) {
      final val = _AgentListResponse(
        agents: $checkedConvert(
          'agents',
          (v) => (v as List<dynamic>)
              .map((e) => AgentSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AgentListResponseToJson(_AgentListResponse instance) =>
    <String, dynamic>{
      'agents': instance.agents.map((e) => e.toJson()).toList(),
    };
