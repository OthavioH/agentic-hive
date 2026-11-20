// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_hello_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerHelloPayload {

 String get serverVersion; int get protocolVersion;
/// Create a copy of ServerHelloPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerHelloPayloadCopyWith<ServerHelloPayload> get copyWith => _$ServerHelloPayloadCopyWithImpl<ServerHelloPayload>(this as ServerHelloPayload, _$identity);

  /// Serializes this ServerHelloPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ServerHelloPayload;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerHelloPayload&&(identical(other.serverVersion, _this.serverVersion) || other.serverVersion == _this.serverVersion)&&(identical(other.protocolVersion, _this.protocolVersion) || other.protocolVersion == _this.protocolVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ServerHelloPayload;
  return Object.hash(runtimeType,_this.serverVersion,_this.protocolVersion);
}

@override
String toString() {
  final _this = this as ServerHelloPayload;
  return 'ServerHelloPayload(serverVersion: ${_this.serverVersion}, protocolVersion: ${_this.protocolVersion})';
}


}

/// @nodoc
abstract mixin class $ServerHelloPayloadCopyWith<$Res>  {
  factory $ServerHelloPayloadCopyWith(ServerHelloPayload value, $Res Function(ServerHelloPayload) _then) = _$ServerHelloPayloadCopyWithImpl;
@useResult
$Res call({
 String serverVersion, int protocolVersion
});




}
/// @nodoc
class _$ServerHelloPayloadCopyWithImpl<$Res>
    implements $ServerHelloPayloadCopyWith<$Res> {
  _$ServerHelloPayloadCopyWithImpl(this._self, this._then);

  final ServerHelloPayload _self;
  final $Res Function(ServerHelloPayload) _then;

/// Create a copy of ServerHelloPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverVersion = null,Object? protocolVersion = null,}) {
  return _then(ServerHelloPayload(
serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerHelloPayload].
extension ServerHelloPayloadPatterns on ServerHelloPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerHelloPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerHelloPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerHelloPayload value)  $default,){
final _that = this;
switch (_that) {
case _ServerHelloPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerHelloPayload value)?  $default,){
final _that = this;
switch (_that) {
case _ServerHelloPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverVersion,  int protocolVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerHelloPayload() when $default != null:
return $default(_that.serverVersion,_that.protocolVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverVersion,  int protocolVersion)  $default,) {final _that = this;
switch (_that) {
case _ServerHelloPayload():
return $default(_that.serverVersion,_that.protocolVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverVersion,  int protocolVersion)?  $default,) {final _that = this;
switch (_that) {
case _ServerHelloPayload() when $default != null:
return $default(_that.serverVersion,_that.protocolVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerHelloPayload implements ServerHelloPayload {
  const _ServerHelloPayload({required this.serverVersion, required this.protocolVersion});
  factory _ServerHelloPayload.fromJson(Map<String, dynamic> json) => _$ServerHelloPayloadFromJson(json);

@override final  String serverVersion;
@override final  int protocolVersion;

/// Create a copy of ServerHelloPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerHelloPayloadCopyWith<_ServerHelloPayload> get copyWith => __$ServerHelloPayloadCopyWithImpl<_ServerHelloPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerHelloPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerHelloPayload&&(identical(other.serverVersion, serverVersion) || other.serverVersion == serverVersion)&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,serverVersion,protocolVersion);
}

@override
String toString() {
    return 'ServerHelloPayload(serverVersion: $serverVersion, protocolVersion: $protocolVersion)';
}


}

/// @nodoc
abstract mixin class _$ServerHelloPayloadCopyWith<$Res> implements $ServerHelloPayloadCopyWith<$Res> {
  factory _$ServerHelloPayloadCopyWith(_ServerHelloPayload value, $Res Function(_ServerHelloPayload) _then) = __$ServerHelloPayloadCopyWithImpl;
@override @useResult
$Res call({
 String serverVersion, int protocolVersion
});




}
/// @nodoc
class __$ServerHelloPayloadCopyWithImpl<$Res>
    implements _$ServerHelloPayloadCopyWith<$Res> {
  __$ServerHelloPayloadCopyWithImpl(this._self, this._then);

  final _ServerHelloPayload _self;
  final $Res Function(_ServerHelloPayload) _then;

/// Create a copy of ServerHelloPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverVersion = null,Object? protocolVersion = null,}) {
  return _then(_ServerHelloPayload(
serverVersion: null == serverVersion ? _self.serverVersion : serverVersion // ignore: cast_nullable_to_non_nullable
as String,protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
