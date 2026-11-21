// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_status_updated_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessStatusUpdatedPayload _$HarnessStatusUpdatedPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_HarnessStatusUpdatedPayload', json, ($checkedConvert) {
  final val = _HarnessStatusUpdatedPayload(
    harness: $checkedConvert(
      'harness',
      (v) => HarnessInfo.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$HarnessStatusUpdatedPayloadToJson(
  _HarnessStatusUpdatedPayload instance,
) => <String, dynamic>{'harness': instance.harness.toJson()};
