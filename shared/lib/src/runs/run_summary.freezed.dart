// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RunSummary {

 String get id; String get workflowName; RunStatus get status; DateTime get startedAt; int get checkpointCount; String? get workflowId; DateTime? get finishedAt;
/// Create a copy of RunSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunSummaryCopyWith<RunSummary> get copyWith => _$RunSummaryCopyWithImpl<RunSummary>(this as RunSummary, _$identity);

  /// Serializes this RunSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workflowName, _this.workflowName) || other.workflowName == _this.workflowName)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.checkpointCount, _this.checkpointCount) || other.checkpointCount == _this.checkpointCount)&&(identical(other.workflowId, _this.workflowId) || other.workflowId == _this.workflowId)&&(identical(other.finishedAt, _this.finishedAt) || other.finishedAt == _this.finishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunSummary;
  return Object.hash(runtimeType,_this.id,_this.workflowName,_this.status,_this.startedAt,_this.checkpointCount,_this.workflowId,_this.finishedAt);
}

@override
String toString() {
  final _this = this as RunSummary;
  return 'RunSummary(id: ${_this.id}, workflowName: ${_this.workflowName}, status: ${_this.status}, startedAt: ${_this.startedAt}, checkpointCount: ${_this.checkpointCount}, workflowId: ${_this.workflowId}, finishedAt: ${_this.finishedAt})';
}


}

/// @nodoc
abstract mixin class $RunSummaryCopyWith<$Res>  {
  factory $RunSummaryCopyWith(RunSummary value, $Res Function(RunSummary) _then) = _$RunSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String workflowName, RunStatus status, DateTime startedAt, int checkpointCount, String? workflowId, DateTime? finishedAt
});




}
/// @nodoc
class _$RunSummaryCopyWithImpl<$Res>
    implements $RunSummaryCopyWith<$Res> {
  _$RunSummaryCopyWithImpl(this._self, this._then);

  final RunSummary _self;
  final $Res Function(RunSummary) _then;

/// Create a copy of RunSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workflowName = null,Object? status = null,Object? startedAt = null,Object? checkpointCount = null,Object? workflowId = freezed,Object? finishedAt = freezed,}) {
  return _then(RunSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowName: null == workflowName ? _self.workflowName : workflowName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RunStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,checkpointCount: null == checkpointCount ? _self.checkpointCount : checkpointCount // ignore: cast_nullable_to_non_nullable
as int,workflowId: freezed == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [RunSummary].
extension RunSummaryPatterns on RunSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunSummary value)  $default,){
final _that = this;
switch (_that) {
case _RunSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunSummary value)?  $default,){
final _that = this;
switch (_that) {
case _RunSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workflowName,  RunStatus status,  DateTime startedAt,  int checkpointCount,  String? workflowId,  DateTime? finishedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunSummary() when $default != null:
return $default(_that.id,_that.workflowName,_that.status,_that.startedAt,_that.checkpointCount,_that.workflowId,_that.finishedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workflowName,  RunStatus status,  DateTime startedAt,  int checkpointCount,  String? workflowId,  DateTime? finishedAt)  $default,) {final _that = this;
switch (_that) {
case _RunSummary():
return $default(_that.id,_that.workflowName,_that.status,_that.startedAt,_that.checkpointCount,_that.workflowId,_that.finishedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workflowName,  RunStatus status,  DateTime startedAt,  int checkpointCount,  String? workflowId,  DateTime? finishedAt)?  $default,) {final _that = this;
switch (_that) {
case _RunSummary() when $default != null:
return $default(_that.id,_that.workflowName,_that.status,_that.startedAt,_that.checkpointCount,_that.workflowId,_that.finishedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunSummary implements RunSummary {
  const _RunSummary({required this.id, required this.workflowName, required this.status, required this.startedAt, required this.checkpointCount, this.workflowId, this.finishedAt});
  factory _RunSummary.fromJson(Map<String, dynamic> json) => _$RunSummaryFromJson(json);

@override final  String id;
@override final  String workflowName;
@override final  RunStatus status;
@override final  DateTime startedAt;
@override final  int checkpointCount;
@override final  String? workflowId;
@override final  DateTime? finishedAt;

/// Create a copy of RunSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunSummaryCopyWith<_RunSummary> get copyWith => __$RunSummaryCopyWithImpl<_RunSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowName, workflowName) || other.workflowName == workflowName)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.checkpointCount, checkpointCount) || other.checkpointCount == checkpointCount)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,workflowName,status,startedAt,checkpointCount,workflowId,finishedAt);
}

@override
String toString() {
    return 'RunSummary(id: $id, workflowName: $workflowName, status: $status, startedAt: $startedAt, checkpointCount: $checkpointCount, workflowId: $workflowId, finishedAt: $finishedAt)';
}


}

/// @nodoc
abstract mixin class _$RunSummaryCopyWith<$Res> implements $RunSummaryCopyWith<$Res> {
  factory _$RunSummaryCopyWith(_RunSummary value, $Res Function(_RunSummary) _then) = __$RunSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String workflowName, RunStatus status, DateTime startedAt, int checkpointCount, String? workflowId, DateTime? finishedAt
});




}
/// @nodoc
class __$RunSummaryCopyWithImpl<$Res>
    implements _$RunSummaryCopyWith<$Res> {
  __$RunSummaryCopyWithImpl(this._self, this._then);

  final _RunSummary _self;
  final $Res Function(_RunSummary) _then;

/// Create a copy of RunSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workflowName = null,Object? status = null,Object? startedAt = null,Object? checkpointCount = null,Object? workflowId = freezed,Object? finishedAt = freezed,}) {
  return _then(_RunSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowName: null == workflowName ? _self.workflowName : workflowName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RunStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,checkpointCount: null == checkpointCount ? _self.checkpointCount : checkpointCount // ignore: cast_nullable_to_non_nullable
as int,workflowId: freezed == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
