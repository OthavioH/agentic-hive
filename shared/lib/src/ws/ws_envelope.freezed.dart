// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ws_envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WsEnvelope {

 String get type; String get id; JsonMap get payload;
/// Create a copy of WsEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WsEnvelopeCopyWith<WsEnvelope> get copyWith => _$WsEnvelopeCopyWithImpl<WsEnvelope>(this as WsEnvelope, _$identity);

  /// Serializes this WsEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WsEnvelope;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WsEnvelope&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.payload, _this.payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WsEnvelope;
  return Object.hash(runtimeType,_this.type,_this.id,const DeepCollectionEquality().hash(_this.payload));
}

@override
String toString() {
  final _this = this as WsEnvelope;
  return 'WsEnvelope(type: ${_this.type}, id: ${_this.id}, payload: ${_this.payload})';
}


}

/// @nodoc
abstract mixin class $WsEnvelopeCopyWith<$Res>  {
  factory $WsEnvelopeCopyWith(WsEnvelope value, $Res Function(WsEnvelope) _then) = _$WsEnvelopeCopyWithImpl;
@useResult
$Res call({
 String type, String id, JsonMap payload
});




}
/// @nodoc
class _$WsEnvelopeCopyWithImpl<$Res>
    implements $WsEnvelopeCopyWith<$Res> {
  _$WsEnvelopeCopyWithImpl(this._self, this._then);

  final WsEnvelope _self;
  final $Res Function(WsEnvelope) _then;

/// Create a copy of WsEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = null,Object? payload = null,}) {
  return _then(WsEnvelope(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}

}


/// Adds pattern-matching-related methods to [WsEnvelope].
extension WsEnvelopePatterns on WsEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WsEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WsEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WsEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _WsEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WsEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _WsEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String id,  JsonMap payload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WsEnvelope() when $default != null:
return $default(_that.type,_that.id,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String id,  JsonMap payload)  $default,) {final _that = this;
switch (_that) {
case _WsEnvelope():
return $default(_that.type,_that.id,_that.payload);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String id,  JsonMap payload)?  $default,) {final _that = this;
switch (_that) {
case _WsEnvelope() when $default != null:
return $default(_that.type,_that.id,_that.payload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WsEnvelope extends WsEnvelope {
  const _WsEnvelope({required this.type, required this.id,  JsonMap payload = const <String, Object?>{}}): _payload = payload,super._();
  factory _WsEnvelope.fromJson(Map<String, dynamic> json) => _$WsEnvelopeFromJson(json);

@override final  String type;
@override final  String id;
 final  JsonMap _payload;
@override@JsonKey() JsonMap get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


/// Create a copy of WsEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WsEnvelopeCopyWith<_WsEnvelope> get copyWith => __$WsEnvelopeCopyWithImpl<_WsEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WsEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WsEnvelope&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,id,const DeepCollectionEquality().hash(_payload));
}

@override
String toString() {
    return 'WsEnvelope(type: $type, id: $id, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$WsEnvelopeCopyWith<$Res> implements $WsEnvelopeCopyWith<$Res> {
  factory _$WsEnvelopeCopyWith(_WsEnvelope value, $Res Function(_WsEnvelope) _then) = __$WsEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 String type, String id, JsonMap payload
});




}
/// @nodoc
class __$WsEnvelopeCopyWithImpl<$Res>
    implements _$WsEnvelopeCopyWith<$Res> {
  __$WsEnvelopeCopyWithImpl(this._self, this._then);

  final _WsEnvelope _self;
  final $Res Function(_WsEnvelope) _then;

/// Create a copy of WsEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = null,Object? payload = null,}) {
  return _then(_WsEnvelope(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}


}

// dart format on
