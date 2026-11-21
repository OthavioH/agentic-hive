// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_edge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkflowEdge {

 String get id; String get sourceNodeId; String get sourceOutput; String get targetNodeId; int? get maxRetries;
/// Create a copy of WorkflowEdge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowEdgeCopyWith<WorkflowEdge> get copyWith => _$WorkflowEdgeCopyWithImpl<WorkflowEdge>(this as WorkflowEdge, _$identity);

  /// Serializes this WorkflowEdge to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowEdge;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowEdge&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceNodeId, _this.sourceNodeId) || other.sourceNodeId == _this.sourceNodeId)&&(identical(other.sourceOutput, _this.sourceOutput) || other.sourceOutput == _this.sourceOutput)&&(identical(other.targetNodeId, _this.targetNodeId) || other.targetNodeId == _this.targetNodeId)&&(identical(other.maxRetries, _this.maxRetries) || other.maxRetries == _this.maxRetries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowEdge;
  return Object.hash(runtimeType,_this.id,_this.sourceNodeId,_this.sourceOutput,_this.targetNodeId,_this.maxRetries);
}

@override
String toString() {
  final _this = this as WorkflowEdge;
  return 'WorkflowEdge(id: ${_this.id}, sourceNodeId: ${_this.sourceNodeId}, sourceOutput: ${_this.sourceOutput}, targetNodeId: ${_this.targetNodeId}, maxRetries: ${_this.maxRetries})';
}


}

/// @nodoc
abstract mixin class $WorkflowEdgeCopyWith<$Res>  {
  factory $WorkflowEdgeCopyWith(WorkflowEdge value, $Res Function(WorkflowEdge) _then) = _$WorkflowEdgeCopyWithImpl;
@useResult
$Res call({
 String id, String sourceNodeId, String sourceOutput, String targetNodeId, int? maxRetries
});




}
/// @nodoc
class _$WorkflowEdgeCopyWithImpl<$Res>
    implements $WorkflowEdgeCopyWith<$Res> {
  _$WorkflowEdgeCopyWithImpl(this._self, this._then);

  final WorkflowEdge _self;
  final $Res Function(WorkflowEdge) _then;

/// Create a copy of WorkflowEdge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceNodeId = null,Object? sourceOutput = null,Object? targetNodeId = null,Object? maxRetries = freezed,}) {
  return _then(WorkflowEdge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sourceNodeId: null == sourceNodeId ? _self.sourceNodeId : sourceNodeId // ignore: cast_nullable_to_non_nullable
as String,sourceOutput: null == sourceOutput ? _self.sourceOutput : sourceOutput // ignore: cast_nullable_to_non_nullable
as String,targetNodeId: null == targetNodeId ? _self.targetNodeId : targetNodeId // ignore: cast_nullable_to_non_nullable
as String,maxRetries: freezed == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowEdge].
extension WorkflowEdgePatterns on WorkflowEdge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowEdge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowEdge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowEdge value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowEdge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowEdge value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowEdge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sourceNodeId,  String sourceOutput,  String targetNodeId,  int? maxRetries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowEdge() when $default != null:
return $default(_that.id,_that.sourceNodeId,_that.sourceOutput,_that.targetNodeId,_that.maxRetries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sourceNodeId,  String sourceOutput,  String targetNodeId,  int? maxRetries)  $default,) {final _that = this;
switch (_that) {
case _WorkflowEdge():
return $default(_that.id,_that.sourceNodeId,_that.sourceOutput,_that.targetNodeId,_that.maxRetries);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sourceNodeId,  String sourceOutput,  String targetNodeId,  int? maxRetries)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowEdge() when $default != null:
return $default(_that.id,_that.sourceNodeId,_that.sourceOutput,_that.targetNodeId,_that.maxRetries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowEdge implements WorkflowEdge {
  const _WorkflowEdge({required this.id, required this.sourceNodeId, required this.sourceOutput, required this.targetNodeId, this.maxRetries});
  factory _WorkflowEdge.fromJson(Map<String, dynamic> json) => _$WorkflowEdgeFromJson(json);

@override final  String id;
@override final  String sourceNodeId;
@override final  String sourceOutput;
@override final  String targetNodeId;
@override final  int? maxRetries;

/// Create a copy of WorkflowEdge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowEdgeCopyWith<_WorkflowEdge> get copyWith => __$WorkflowEdgeCopyWithImpl<_WorkflowEdge>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowEdgeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowEdge&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceNodeId, sourceNodeId) || other.sourceNodeId == sourceNodeId)&&(identical(other.sourceOutput, sourceOutput) || other.sourceOutput == sourceOutput)&&(identical(other.targetNodeId, targetNodeId) || other.targetNodeId == targetNodeId)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceNodeId,sourceOutput,targetNodeId,maxRetries);
}

@override
String toString() {
    return 'WorkflowEdge(id: $id, sourceNodeId: $sourceNodeId, sourceOutput: $sourceOutput, targetNodeId: $targetNodeId, maxRetries: $maxRetries)';
}


}

/// @nodoc
abstract mixin class _$WorkflowEdgeCopyWith<$Res> implements $WorkflowEdgeCopyWith<$Res> {
  factory _$WorkflowEdgeCopyWith(_WorkflowEdge value, $Res Function(_WorkflowEdge) _then) = __$WorkflowEdgeCopyWithImpl;
@override @useResult
$Res call({
 String id, String sourceNodeId, String sourceOutput, String targetNodeId, int? maxRetries
});




}
/// @nodoc
class __$WorkflowEdgeCopyWithImpl<$Res>
    implements _$WorkflowEdgeCopyWith<$Res> {
  __$WorkflowEdgeCopyWithImpl(this._self, this._then);

  final _WorkflowEdge _self;
  final $Res Function(_WorkflowEdge) _then;

/// Create a copy of WorkflowEdge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceNodeId = null,Object? sourceOutput = null,Object? targetNodeId = null,Object? maxRetries = freezed,}) {
  return _then(_WorkflowEdge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sourceNodeId: null == sourceNodeId ? _self.sourceNodeId : sourceNodeId // ignore: cast_nullable_to_non_nullable
as String,sourceOutput: null == sourceOutput ? _self.sourceOutput : sourceOutput // ignore: cast_nullable_to_non_nullable
as String,targetNodeId: null == targetNodeId ? _self.targetNodeId : targetNodeId // ignore: cast_nullable_to_non_nullable
as String,maxRetries: freezed == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
