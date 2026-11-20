// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiError _$ApiErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ApiError', json, ($checkedConvert) {
      final val = _ApiError(
        code: $checkedConvert('code', (v) => v as String),
        message: $checkedConvert('message', (v) => v as String),
        requestId: $checkedConvert('requestId', (v) => v as String?),
      );
      return val;
    });
