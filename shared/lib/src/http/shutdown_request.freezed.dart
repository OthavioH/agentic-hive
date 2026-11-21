// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shutdown_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ShutdownRequest {

 bool get force;
/// Create a copy of ShutdownRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShutdownRequestCopyWith<ShutdownRequest> get copyWith => _$ShutdownRequestCopyWithImpl<ShutdownRequest>(this as ShutdownRequest, _$identity);

  /// Serializes this ShutdownRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ShutdownRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShutdownRequest&&(identical(other.force, _this.force) || other.force == _this.force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ShutdownRequest;
  return Object.hash(runtimeType,_this.force);
}

@override
String toString() {
  final _this = this as ShutdownRequest;
  return 'ShutdownRequest(force: ${_this.force})';
}


}

/// @nodoc
abstract mixin class $ShutdownRequestCopyWith<$Res>  {
  factory $ShutdownRequestCopyWith(ShutdownRequest value, $Res Function(ShutdownRequest) _then) = _$ShutdownRequestCopyWithImpl;
@useResult
$Res call({
 bool force
});




}
/// @nodoc
class _$ShutdownRequestCopyWithImpl<$Res>
    implements $ShutdownRequestCopyWith<$Res> {
  _$ShutdownRequestCopyWithImpl(this._self, this._then);

  final ShutdownRequest _self;
  final $Res Function(ShutdownRequest) _then;

/// Create a copy of ShutdownRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? force = null,}) {
  return _then(ShutdownRequest(
force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ShutdownRequest].
extension ShutdownRequestPatterns on ShutdownRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShutdownRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShutdownRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShutdownRequest value)  $default,){
final _that = this;
switch (_that) {
case _ShutdownRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShutdownRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ShutdownRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool force)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShutdownRequest() when $default != null:
return $default(_that.force);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool force)  $default,) {final _that = this;
switch (_that) {
case _ShutdownRequest():
return $default(_that.force);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool force)?  $default,) {final _that = this;
switch (_that) {
case _ShutdownRequest() when $default != null:
return $default(_that.force);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShutdownRequest implements ShutdownRequest {
  const _ShutdownRequest({this.force = false});
  factory _ShutdownRequest.fromJson(Map<String, dynamic> json) => _$ShutdownRequestFromJson(json);

@override@JsonKey() final  bool force;

/// Create a copy of ShutdownRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShutdownRequestCopyWith<_ShutdownRequest> get copyWith => __$ShutdownRequestCopyWithImpl<_ShutdownRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShutdownRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShutdownRequest&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,force);
}

@override
String toString() {
    return 'ShutdownRequest(force: $force)';
}


}

/// @nodoc
abstract mixin class _$ShutdownRequestCopyWith<$Res> implements $ShutdownRequestCopyWith<$Res> {
  factory _$ShutdownRequestCopyWith(_ShutdownRequest value, $Res Function(_ShutdownRequest) _then) = __$ShutdownRequestCopyWithImpl;
@override @useResult
$Res call({
 bool force
});




}
/// @nodoc
class __$ShutdownRequestCopyWithImpl<$Res>
    implements _$ShutdownRequestCopyWith<$Res> {
  __$ShutdownRequestCopyWithImpl(this._self, this._then);

  final _ShutdownRequest _self;
  final $Res Function(_ShutdownRequest) _then;

/// Create a copy of ShutdownRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? force = null,}) {
  return _then(_ShutdownRequest(
force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
