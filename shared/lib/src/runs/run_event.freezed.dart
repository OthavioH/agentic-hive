// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RunEvent {

 String get id; String get runId; int get sequence; RunEventType get type; DateTime get createdAt; String? get nodeId; String? get edgeId; JsonMap get payload;
/// Create a copy of RunEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunEventCopyWith<RunEvent> get copyWith => _$RunEventCopyWithImpl<RunEvent>(this as RunEvent, _$identity);

  /// Serializes this RunEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.runId, _this.runId) || other.runId == _this.runId)&&(identical(other.sequence, _this.sequence) || other.sequence == _this.sequence)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.nodeId, _this.nodeId) || other.nodeId == _this.nodeId)&&(identical(other.edgeId, _this.edgeId) || other.edgeId == _this.edgeId)&&const DeepCollectionEquality().equals(other.payload, _this.payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunEvent;
  return Object.hash(runtimeType,_this.id,_this.runId,_this.sequence,_this.type,_this.createdAt,_this.nodeId,_this.edgeId,const DeepCollectionEquality().hash(_this.payload));
}

@override
String toString() {
  final _this = this as RunEvent;
  return 'RunEvent(id: ${_this.id}, runId: ${_this.runId}, sequence: ${_this.sequence}, type: ${_this.type}, createdAt: ${_this.createdAt}, nodeId: ${_this.nodeId}, edgeId: ${_this.edgeId}, payload: ${_this.payload})';
}


}

/// @nodoc
abstract mixin class $RunEventCopyWith<$Res>  {
  factory $RunEventCopyWith(RunEvent value, $Res Function(RunEvent) _then) = _$RunEventCopyWithImpl;
@useResult
$Res call({
 String id, String runId, int sequence, RunEventType type, DateTime createdAt, String? nodeId, String? edgeId, JsonMap payload
});




}
/// @nodoc
class _$RunEventCopyWithImpl<$Res>
    implements $RunEventCopyWith<$Res> {
  _$RunEventCopyWithImpl(this._self, this._then);

  final RunEvent _self;
  final $Res Function(RunEvent) _then;

/// Create a copy of RunEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? runId = null,Object? sequence = null,Object? type = null,Object? createdAt = null,Object? nodeId = freezed,Object? edgeId = freezed,Object? payload = null,}) {
  return _then(RunEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RunEventType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,nodeId: freezed == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String?,edgeId: freezed == edgeId ? _self.edgeId : edgeId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}

}


/// Adds pattern-matching-related methods to [RunEvent].
extension RunEventPatterns on RunEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunEvent value)  $default,){
final _that = this;
switch (_that) {
case _RunEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunEvent value)?  $default,){
final _that = this;
switch (_that) {
case _RunEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String runId,  int sequence,  RunEventType type,  DateTime createdAt,  String? nodeId,  String? edgeId,  JsonMap payload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunEvent() when $default != null:
return $default(_that.id,_that.runId,_that.sequence,_that.type,_that.createdAt,_that.nodeId,_that.edgeId,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String runId,  int sequence,  RunEventType type,  DateTime createdAt,  String? nodeId,  String? edgeId,  JsonMap payload)  $default,) {final _that = this;
switch (_that) {
case _RunEvent():
return $default(_that.id,_that.runId,_that.sequence,_that.type,_that.createdAt,_that.nodeId,_that.edgeId,_that.payload);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String runId,  int sequence,  RunEventType type,  DateTime createdAt,  String? nodeId,  String? edgeId,  JsonMap payload)?  $default,) {final _that = this;
switch (_that) {
case _RunEvent() when $default != null:
return $default(_that.id,_that.runId,_that.sequence,_that.type,_that.createdAt,_that.nodeId,_that.edgeId,_that.payload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunEvent implements RunEvent {
  const _RunEvent({required this.id, required this.runId, required this.sequence, required this.type, required this.createdAt, this.nodeId, this.edgeId,  JsonMap payload = const <String, Object?>{}}): _payload = payload;
  factory _RunEvent.fromJson(Map<String, dynamic> json) => _$RunEventFromJson(json);

@override final  String id;
@override final  String runId;
@override final  int sequence;
@override final  RunEventType type;
@override final  DateTime createdAt;
@override final  String? nodeId;
@override final  String? edgeId;
 final  JsonMap _payload;
@override@JsonKey() JsonMap get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


/// Create a copy of RunEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunEventCopyWith<_RunEvent> get copyWith => __$RunEventCopyWithImpl<_RunEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.type, type) || other.type == type)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.edgeId, edgeId) || other.edgeId == edgeId)&&const DeepCollectionEquality().equals(other.payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,runId,sequence,type,createdAt,nodeId,edgeId,const DeepCollectionEquality().hash(_payload));
}

@override
String toString() {
    return 'RunEvent(id: $id, runId: $runId, sequence: $sequence, type: $type, createdAt: $createdAt, nodeId: $nodeId, edgeId: $edgeId, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$RunEventCopyWith<$Res> implements $RunEventCopyWith<$Res> {
  factory _$RunEventCopyWith(_RunEvent value, $Res Function(_RunEvent) _then) = __$RunEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String runId, int sequence, RunEventType type, DateTime createdAt, String? nodeId, String? edgeId, JsonMap payload
});




}
/// @nodoc
class __$RunEventCopyWithImpl<$Res>
    implements _$RunEventCopyWith<$Res> {
  __$RunEventCopyWithImpl(this._self, this._then);

  final _RunEvent _self;
  final $Res Function(_RunEvent) _then;

/// Create a copy of RunEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? runId = null,Object? sequence = null,Object? type = null,Object? createdAt = null,Object? nodeId = freezed,Object? edgeId = freezed,Object? payload = null,}) {
  return _then(_RunEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RunEventType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,nodeId: freezed == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String?,edgeId: freezed == edgeId ? _self.edgeId : edgeId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}


}

// dart format on
