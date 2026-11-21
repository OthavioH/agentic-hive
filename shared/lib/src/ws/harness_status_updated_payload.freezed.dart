// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_status_updated_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessStatusUpdatedPayload {

 HarnessInfo get harness;
/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HarnessStatusUpdatedPayloadCopyWith<HarnessStatusUpdatedPayload> get copyWith => _$HarnessStatusUpdatedPayloadCopyWithImpl<HarnessStatusUpdatedPayload>(this as HarnessStatusUpdatedPayload, _$identity);

  /// Serializes this HarnessStatusUpdatedPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HarnessStatusUpdatedPayload;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HarnessStatusUpdatedPayload&&(identical(other.harness, _this.harness) || other.harness == _this.harness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HarnessStatusUpdatedPayload;
  return Object.hash(runtimeType,_this.harness);
}

@override
String toString() {
  final _this = this as HarnessStatusUpdatedPayload;
  return 'HarnessStatusUpdatedPayload(harness: ${_this.harness})';
}


}

/// @nodoc
abstract mixin class $HarnessStatusUpdatedPayloadCopyWith<$Res>  {
  factory $HarnessStatusUpdatedPayloadCopyWith(HarnessStatusUpdatedPayload value, $Res Function(HarnessStatusUpdatedPayload) _then) = _$HarnessStatusUpdatedPayloadCopyWithImpl;
@useResult
$Res call({
 HarnessInfo harness
});


$HarnessInfoCopyWith<$Res> get harness;

}
/// @nodoc
class _$HarnessStatusUpdatedPayloadCopyWithImpl<$Res>
    implements $HarnessStatusUpdatedPayloadCopyWith<$Res> {
  _$HarnessStatusUpdatedPayloadCopyWithImpl(this._self, this._then);

  final HarnessStatusUpdatedPayload _self;
  final $Res Function(HarnessStatusUpdatedPayload) _then;

/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? harness = null,}) {
  return _then(HarnessStatusUpdatedPayload(
harness: null == harness ? _self.harness : harness // ignore: cast_nullable_to_non_nullable
as HarnessInfo,
  ));
}
/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HarnessInfoCopyWith<$Res> get harness {
  
  return $HarnessInfoCopyWith<$Res>(_self.harness, (value) {
    return _then(_self.copyWith(harness: value));
  });
}
}


/// Adds pattern-matching-related methods to [HarnessStatusUpdatedPayload].
extension HarnessStatusUpdatedPayloadPatterns on HarnessStatusUpdatedPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HarnessStatusUpdatedPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HarnessStatusUpdatedPayload value)  $default,){
final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HarnessStatusUpdatedPayload value)?  $default,){
final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HarnessInfo harness)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload() when $default != null:
return $default(_that.harness);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HarnessInfo harness)  $default,) {final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload():
return $default(_that.harness);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HarnessInfo harness)?  $default,) {final _that = this;
switch (_that) {
case _HarnessStatusUpdatedPayload() when $default != null:
return $default(_that.harness);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HarnessStatusUpdatedPayload implements HarnessStatusUpdatedPayload {
  const _HarnessStatusUpdatedPayload({required this.harness});
  factory _HarnessStatusUpdatedPayload.fromJson(Map<String, dynamic> json) => _$HarnessStatusUpdatedPayloadFromJson(json);

@override final  HarnessInfo harness;

/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HarnessStatusUpdatedPayloadCopyWith<_HarnessStatusUpdatedPayload> get copyWith => __$HarnessStatusUpdatedPayloadCopyWithImpl<_HarnessStatusUpdatedPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HarnessStatusUpdatedPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HarnessStatusUpdatedPayload&&(identical(other.harness, harness) || other.harness == harness));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,harness);
}

@override
String toString() {
    return 'HarnessStatusUpdatedPayload(harness: $harness)';
}


}

/// @nodoc
abstract mixin class _$HarnessStatusUpdatedPayloadCopyWith<$Res> implements $HarnessStatusUpdatedPayloadCopyWith<$Res> {
  factory _$HarnessStatusUpdatedPayloadCopyWith(_HarnessStatusUpdatedPayload value, $Res Function(_HarnessStatusUpdatedPayload) _then) = __$HarnessStatusUpdatedPayloadCopyWithImpl;
@override @useResult
$Res call({
 HarnessInfo harness
});


@override $HarnessInfoCopyWith<$Res> get harness;

}
/// @nodoc
class __$HarnessStatusUpdatedPayloadCopyWithImpl<$Res>
    implements _$HarnessStatusUpdatedPayloadCopyWith<$Res> {
  __$HarnessStatusUpdatedPayloadCopyWithImpl(this._self, this._then);

  final _HarnessStatusUpdatedPayload _self;
  final $Res Function(_HarnessStatusUpdatedPayload) _then;

/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? harness = null,}) {
  return _then(_HarnessStatusUpdatedPayload(
harness: null == harness ? _self.harness : harness // ignore: cast_nullable_to_non_nullable
as HarnessInfo,
  ));
}

/// Create a copy of HarnessStatusUpdatedPayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HarnessInfoCopyWith<$Res> get harness {
  
  return $HarnessInfoCopyWith<$Res>(_self.harness, (value) {
    return _then(_self.copyWith(harness: value));
  });
}
}

// dart format on
