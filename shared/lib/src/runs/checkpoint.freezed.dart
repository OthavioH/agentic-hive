// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checkpoint.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Checkpoint {

 String get id; String get runId; int get sequence; List<String> get pendingNodeIds; Map<String, int> get attemptsByEdge; int get circuitBreakerCount; Map<String, JsonMap> get nodeOutputs; DateTime get createdAt; String? get completedNodeId;
/// Create a copy of Checkpoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckpointCopyWith<Checkpoint> get copyWith => _$CheckpointCopyWithImpl<Checkpoint>(this as Checkpoint, _$identity);

  /// Serializes this Checkpoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Checkpoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Checkpoint&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.runId, _this.runId) || other.runId == _this.runId)&&(identical(other.sequence, _this.sequence) || other.sequence == _this.sequence)&&const DeepCollectionEquality().equals(other.pendingNodeIds, _this.pendingNodeIds)&&const DeepCollectionEquality().equals(other.attemptsByEdge, _this.attemptsByEdge)&&(identical(other.circuitBreakerCount, _this.circuitBreakerCount) || other.circuitBreakerCount == _this.circuitBreakerCount)&&const DeepCollectionEquality().equals(other.nodeOutputs, _this.nodeOutputs)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.completedNodeId, _this.completedNodeId) || other.completedNodeId == _this.completedNodeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Checkpoint;
  return Object.hash(runtimeType,_this.id,_this.runId,_this.sequence,const DeepCollectionEquality().hash(_this.pendingNodeIds),const DeepCollectionEquality().hash(_this.attemptsByEdge),_this.circuitBreakerCount,const DeepCollectionEquality().hash(_this.nodeOutputs),_this.createdAt,_this.completedNodeId);
}

@override
String toString() {
  final _this = this as Checkpoint;
  return 'Checkpoint(id: ${_this.id}, runId: ${_this.runId}, sequence: ${_this.sequence}, pendingNodeIds: ${_this.pendingNodeIds}, attemptsByEdge: ${_this.attemptsByEdge}, circuitBreakerCount: ${_this.circuitBreakerCount}, nodeOutputs: ${_this.nodeOutputs}, createdAt: ${_this.createdAt}, completedNodeId: ${_this.completedNodeId})';
}


}

/// @nodoc
abstract mixin class $CheckpointCopyWith<$Res>  {
  factory $CheckpointCopyWith(Checkpoint value, $Res Function(Checkpoint) _then) = _$CheckpointCopyWithImpl;
@useResult
$Res call({
 String id, String runId, int sequence, List<String> pendingNodeIds, Map<String, int> attemptsByEdge, int circuitBreakerCount, Map<String, JsonMap> nodeOutputs, DateTime createdAt, String? completedNodeId
});




}
/// @nodoc
class _$CheckpointCopyWithImpl<$Res>
    implements $CheckpointCopyWith<$Res> {
  _$CheckpointCopyWithImpl(this._self, this._then);

  final Checkpoint _self;
  final $Res Function(Checkpoint) _then;

/// Create a copy of Checkpoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? runId = null,Object? sequence = null,Object? pendingNodeIds = null,Object? attemptsByEdge = null,Object? circuitBreakerCount = null,Object? nodeOutputs = null,Object? createdAt = null,Object? completedNodeId = freezed,}) {
  return _then(Checkpoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,pendingNodeIds: null == pendingNodeIds ? _self.pendingNodeIds : pendingNodeIds // ignore: cast_nullable_to_non_nullable
as List<String>,attemptsByEdge: null == attemptsByEdge ? _self.attemptsByEdge : attemptsByEdge // ignore: cast_nullable_to_non_nullable
as Map<String, int>,circuitBreakerCount: null == circuitBreakerCount ? _self.circuitBreakerCount : circuitBreakerCount // ignore: cast_nullable_to_non_nullable
as int,nodeOutputs: null == nodeOutputs ? _self.nodeOutputs : nodeOutputs // ignore: cast_nullable_to_non_nullable
as Map<String, JsonMap>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedNodeId: freezed == completedNodeId ? _self.completedNodeId : completedNodeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Checkpoint].
extension CheckpointPatterns on Checkpoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Checkpoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Checkpoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Checkpoint value)  $default,){
final _that = this;
switch (_that) {
case _Checkpoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Checkpoint value)?  $default,){
final _that = this;
switch (_that) {
case _Checkpoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String runId,  int sequence,  List<String> pendingNodeIds,  Map<String, int> attemptsByEdge,  int circuitBreakerCount,  Map<String, JsonMap> nodeOutputs,  DateTime createdAt,  String? completedNodeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Checkpoint() when $default != null:
return $default(_that.id,_that.runId,_that.sequence,_that.pendingNodeIds,_that.attemptsByEdge,_that.circuitBreakerCount,_that.nodeOutputs,_that.createdAt,_that.completedNodeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String runId,  int sequence,  List<String> pendingNodeIds,  Map<String, int> attemptsByEdge,  int circuitBreakerCount,  Map<String, JsonMap> nodeOutputs,  DateTime createdAt,  String? completedNodeId)  $default,) {final _that = this;
switch (_that) {
case _Checkpoint():
return $default(_that.id,_that.runId,_that.sequence,_that.pendingNodeIds,_that.attemptsByEdge,_that.circuitBreakerCount,_that.nodeOutputs,_that.createdAt,_that.completedNodeId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String runId,  int sequence,  List<String> pendingNodeIds,  Map<String, int> attemptsByEdge,  int circuitBreakerCount,  Map<String, JsonMap> nodeOutputs,  DateTime createdAt,  String? completedNodeId)?  $default,) {final _that = this;
switch (_that) {
case _Checkpoint() when $default != null:
return $default(_that.id,_that.runId,_that.sequence,_that.pendingNodeIds,_that.attemptsByEdge,_that.circuitBreakerCount,_that.nodeOutputs,_that.createdAt,_that.completedNodeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Checkpoint implements Checkpoint {
  const _Checkpoint({required this.id, required this.runId, required this.sequence, required  List<String> pendingNodeIds, required  Map<String, int> attemptsByEdge, required this.circuitBreakerCount, required  Map<String, JsonMap> nodeOutputs, required this.createdAt, this.completedNodeId}): _pendingNodeIds = pendingNodeIds,_attemptsByEdge = attemptsByEdge,_nodeOutputs = nodeOutputs;
  factory _Checkpoint.fromJson(Map<String, dynamic> json) => _$CheckpointFromJson(json);

@override final  String id;
@override final  String runId;
@override final  int sequence;
 final  List<String> _pendingNodeIds;
@override List<String> get pendingNodeIds {
  if (_pendingNodeIds is EqualUnmodifiableListView) return _pendingNodeIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingNodeIds);
}

 final  Map<String, int> _attemptsByEdge;
@override Map<String, int> get attemptsByEdge {
  if (_attemptsByEdge is EqualUnmodifiableMapView) return _attemptsByEdge;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_attemptsByEdge);
}

@override final  int circuitBreakerCount;
 final  Map<String, JsonMap> _nodeOutputs;
@override Map<String, JsonMap> get nodeOutputs {
  if (_nodeOutputs is EqualUnmodifiableMapView) return _nodeOutputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_nodeOutputs);
}

@override final  DateTime createdAt;
@override final  String? completedNodeId;

/// Create a copy of Checkpoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckpointCopyWith<_Checkpoint> get copyWith => __$CheckpointCopyWithImpl<_Checkpoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CheckpointToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Checkpoint&&(identical(other.id, id) || other.id == id)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&const DeepCollectionEquality().equals(other.pendingNodeIds, _pendingNodeIds)&&const DeepCollectionEquality().equals(other.attemptsByEdge, _attemptsByEdge)&&(identical(other.circuitBreakerCount, circuitBreakerCount) || other.circuitBreakerCount == circuitBreakerCount)&&const DeepCollectionEquality().equals(other.nodeOutputs, _nodeOutputs)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedNodeId, completedNodeId) || other.completedNodeId == completedNodeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,runId,sequence,const DeepCollectionEquality().hash(_pendingNodeIds),const DeepCollectionEquality().hash(_attemptsByEdge),circuitBreakerCount,const DeepCollectionEquality().hash(_nodeOutputs),createdAt,completedNodeId);
}

@override
String toString() {
    return 'Checkpoint(id: $id, runId: $runId, sequence: $sequence, pendingNodeIds: $pendingNodeIds, attemptsByEdge: $attemptsByEdge, circuitBreakerCount: $circuitBreakerCount, nodeOutputs: $nodeOutputs, createdAt: $createdAt, completedNodeId: $completedNodeId)';
}


}

/// @nodoc
abstract mixin class _$CheckpointCopyWith<$Res> implements $CheckpointCopyWith<$Res> {
  factory _$CheckpointCopyWith(_Checkpoint value, $Res Function(_Checkpoint) _then) = __$CheckpointCopyWithImpl;
@override @useResult
$Res call({
 String id, String runId, int sequence, List<String> pendingNodeIds, Map<String, int> attemptsByEdge, int circuitBreakerCount, Map<String, JsonMap> nodeOutputs, DateTime createdAt, String? completedNodeId
});




}
/// @nodoc
class __$CheckpointCopyWithImpl<$Res>
    implements _$CheckpointCopyWith<$Res> {
  __$CheckpointCopyWithImpl(this._self, this._then);

  final _Checkpoint _self;
  final $Res Function(_Checkpoint) _then;

/// Create a copy of Checkpoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? runId = null,Object? sequence = null,Object? pendingNodeIds = null,Object? attemptsByEdge = null,Object? circuitBreakerCount = null,Object? nodeOutputs = null,Object? createdAt = null,Object? completedNodeId = freezed,}) {
  return _then(_Checkpoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,pendingNodeIds: null == pendingNodeIds ? _self._pendingNodeIds : pendingNodeIds // ignore: cast_nullable_to_non_nullable
as List<String>,attemptsByEdge: null == attemptsByEdge ? _self._attemptsByEdge : attemptsByEdge // ignore: cast_nullable_to_non_nullable
as Map<String, int>,circuitBreakerCount: null == circuitBreakerCount ? _self.circuitBreakerCount : circuitBreakerCount // ignore: cast_nullable_to_non_nullable
as int,nodeOutputs: null == nodeOutputs ? _self._nodeOutputs : nodeOutputs // ignore: cast_nullable_to_non_nullable
as Map<String, JsonMap>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedNodeId: freezed == completedNodeId ? _self.completedNodeId : completedNodeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
