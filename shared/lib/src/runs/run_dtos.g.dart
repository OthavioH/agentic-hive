// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RunsListResponse _$RunsListResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_RunsListResponse', json, ($checkedConvert) {
      final val = _RunsListResponse(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => RunSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        total: $checkedConvert('total', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$RunsListResponseToJson(_RunsListResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
    };

_RunEventsResponse _$RunEventsResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_RunEventsResponse', json, ($checkedConvert) {
      final val = _RunEventsResponse(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => RunEvent.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        lastSequence: $checkedConvert(
          'lastSequence',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RunEventsResponseToJson(_RunEventsResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'lastSequence': instance.lastSequence,
    };

_RunCheckpointsResponse _$RunCheckpointsResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_RunCheckpointsResponse', json, ($checkedConvert) {
  final val = _RunCheckpointsResponse(
    items: $checkedConvert(
      'items',
      (v) => (v as List<dynamic>)
          .map((e) => Checkpoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$RunCheckpointsResponseToJson(
  _RunCheckpointsResponse instance,
) => <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
