// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agents_changed_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentsChangedPayload _$AgentsChangedPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_AgentsChangedPayload', json, ($checkedConvert) {
  final val = _AgentsChangedPayload(
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(_$AgentChangeKindEnumMap, v),
    ),
    id: $checkedConvert('id', (v) => v as String),
    agent: $checkedConvert(
      'agent',
      (v) =>
          v == null ? null : AgentSummary.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$AgentsChangedPayloadToJson(
  _AgentsChangedPayload instance,
) => <String, dynamic>{
  'kind': _$AgentChangeKindEnumMap[instance.kind]!,
  'id': instance.id,
  'agent': ?instance.agent?.toJson(),
};

const _$AgentChangeKindEnumMap = {
  AgentChangeKind.created: 'created',
  AgentChangeKind.updated: 'updated',
  AgentChangeKind.deleted: 'deleted',
};
