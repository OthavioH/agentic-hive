// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessListResponse _$HarnessListResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HarnessListResponse', json, ($checkedConvert) {
      final val = _HarnessListResponse(
        harnesses: $checkedConvert(
          'harnesses',
          (v) => (v as List<dynamic>)
              .map((e) => HarnessInfo.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HarnessListResponseToJson(
  _HarnessListResponse instance,
) => <String, dynamic>{
  'harnesses': instance.harnesses.map((e) => e.toJson()).toList(),
};
