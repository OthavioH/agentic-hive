// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessListResponse {

 List<HarnessInfo> get harnesses;
/// Create a copy of HarnessListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HarnessListResponseCopyWith<HarnessListResponse> get copyWith => _$HarnessListResponseCopyWithImpl<HarnessListResponse>(this as HarnessListResponse, _$identity);

  /// Serializes this HarnessListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HarnessListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HarnessListResponse&&const DeepCollectionEquality().equals(other.harnesses, _this.harnesses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HarnessListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.harnesses));
}

@override
String toString() {
  final _this = this as HarnessListResponse;
  return 'HarnessListResponse(harnesses: ${_this.harnesses})';
}


}

/// @nodoc
abstract mixin class $HarnessListResponseCopyWith<$Res>  {
  factory $HarnessListResponseCopyWith(HarnessListResponse value, $Res Function(HarnessListResponse) _then) = _$HarnessListResponseCopyWithImpl;
@useResult
$Res call({
 List<HarnessInfo> harnesses
});




}
/// @nodoc
class _$HarnessListResponseCopyWithImpl<$Res>
    implements $HarnessListResponseCopyWith<$Res> {
  _$HarnessListResponseCopyWithImpl(this._self, this._then);

  final HarnessListResponse _self;
  final $Res Function(HarnessListResponse) _then;

/// Create a copy of HarnessListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? harnesses = null,}) {
  return _then(HarnessListResponse(
harnesses: null == harnesses ? _self.harnesses : harnesses // ignore: cast_nullable_to_non_nullable
as List<HarnessInfo>,
  ));
}

}


/// Adds pattern-matching-related methods to [HarnessListResponse].
extension HarnessListResponsePatterns on HarnessListResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HarnessListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HarnessListResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HarnessListResponse value)  $default,){
final _that = this;
switch (_that) {
case _HarnessListResponse():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HarnessListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HarnessListResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<HarnessInfo> harnesses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HarnessListResponse() when $default != null:
return $default(_that.harnesses);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<HarnessInfo> harnesses)  $default,) {final _that = this;
switch (_that) {
case _HarnessListResponse():
return $default(_that.harnesses);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<HarnessInfo> harnesses)?  $default,) {final _that = this;
switch (_that) {
case _HarnessListResponse() when $default != null:
return $default(_that.harnesses);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HarnessListResponse implements HarnessListResponse {
  const _HarnessListResponse({required  List<HarnessInfo> harnesses}): _harnesses = harnesses;
  factory _HarnessListResponse.fromJson(Map<String, dynamic> json) => _$HarnessListResponseFromJson(json);

 final  List<HarnessInfo> _harnesses;
@override List<HarnessInfo> get harnesses {
  if (_harnesses is EqualUnmodifiableListView) return _harnesses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_harnesses);
}


/// Create a copy of HarnessListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HarnessListResponseCopyWith<_HarnessListResponse> get copyWith => __$HarnessListResponseCopyWithImpl<_HarnessListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HarnessListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HarnessListResponse&&const DeepCollectionEquality().equals(other.harnesses, _harnesses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_harnesses));
}

@override
String toString() {
    return 'HarnessListResponse(harnesses: $harnesses)';
}


}

/// @nodoc
abstract mixin class _$HarnessListResponseCopyWith<$Res> implements $HarnessListResponseCopyWith<$Res> {
  factory _$HarnessListResponseCopyWith(_HarnessListResponse value, $Res Function(_HarnessListResponse) _then) = __$HarnessListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<HarnessInfo> harnesses
});




}
/// @nodoc
class __$HarnessListResponseCopyWithImpl<$Res>
    implements _$HarnessListResponseCopyWith<$Res> {
  __$HarnessListResponseCopyWithImpl(this._self, this._then);

  final _HarnessListResponse _self;
  final $Res Function(_HarnessListResponse) _then;

/// Create a copy of HarnessListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? harnesses = null,}) {
  return _then(_HarnessListResponse(
harnesses: null == harnesses ? _self._harnesses : harnesses // ignore: cast_nullable_to_non_nullable
as List<HarnessInfo>,
  ));
}


}

// dart format on
