// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Run {

 String get id; String get workflowName; Workflow get workflowDefinition; String get workspacePath; RunStatus get status; DateTime get startedAt; String? get workflowId; DateTime? get finishedAt; String? get errorMessage;
/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunCopyWith<Run> get copyWith => _$RunCopyWithImpl<Run>(this as Run, _$identity);

  /// Serializes this Run to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Run;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Run&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workflowName, _this.workflowName) || other.workflowName == _this.workflowName)&&(identical(other.workflowDefinition, _this.workflowDefinition) || other.workflowDefinition == _this.workflowDefinition)&&(identical(other.workspacePath, _this.workspacePath) || other.workspacePath == _this.workspacePath)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.workflowId, _this.workflowId) || other.workflowId == _this.workflowId)&&(identical(other.finishedAt, _this.finishedAt) || other.finishedAt == _this.finishedAt)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Run;
  return Object.hash(runtimeType,_this.id,_this.workflowName,_this.workflowDefinition,_this.workspacePath,_this.status,_this.startedAt,_this.workflowId,_this.finishedAt,_this.errorMessage);
}

@override
String toString() {
  final _this = this as Run;
  return 'Run(id: ${_this.id}, workflowName: ${_this.workflowName}, workflowDefinition: ${_this.workflowDefinition}, workspacePath: ${_this.workspacePath}, status: ${_this.status}, startedAt: ${_this.startedAt}, workflowId: ${_this.workflowId}, finishedAt: ${_this.finishedAt}, errorMessage: ${_this.errorMessage})';
}


}

/// @nodoc
abstract mixin class $RunCopyWith<$Res>  {
  factory $RunCopyWith(Run value, $Res Function(Run) _then) = _$RunCopyWithImpl;
@useResult
$Res call({
 String id, String workflowName, Workflow workflowDefinition, String workspacePath, RunStatus status, DateTime startedAt, String? workflowId, DateTime? finishedAt, String? errorMessage
});


$WorkflowCopyWith<$Res> get workflowDefinition;

}
/// @nodoc
class _$RunCopyWithImpl<$Res>
    implements $RunCopyWith<$Res> {
  _$RunCopyWithImpl(this._self, this._then);

  final Run _self;
  final $Res Function(Run) _then;

/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workflowName = null,Object? workflowDefinition = null,Object? workspacePath = null,Object? status = null,Object? startedAt = null,Object? workflowId = freezed,Object? finishedAt = freezed,Object? errorMessage = freezed,}) {
  return _then(Run(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowName: null == workflowName ? _self.workflowName : workflowName // ignore: cast_nullable_to_non_nullable
as String,workflowDefinition: null == workflowDefinition ? _self.workflowDefinition : workflowDefinition // ignore: cast_nullable_to_non_nullable
as Workflow,workspacePath: null == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RunStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,workflowId: freezed == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflowDefinition {
  
  return $WorkflowCopyWith<$Res>(_self.workflowDefinition, (value) {
    return _then(_self.copyWith(workflowDefinition: value));
  });
}
}


/// Adds pattern-matching-related methods to [Run].
extension RunPatterns on Run {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Run value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Run() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Run value)  $default,){
final _that = this;
switch (_that) {
case _Run():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Run value)?  $default,){
final _that = this;
switch (_that) {
case _Run() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workflowName,  Workflow workflowDefinition,  String workspacePath,  RunStatus status,  DateTime startedAt,  String? workflowId,  DateTime? finishedAt,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Run() when $default != null:
return $default(_that.id,_that.workflowName,_that.workflowDefinition,_that.workspacePath,_that.status,_that.startedAt,_that.workflowId,_that.finishedAt,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workflowName,  Workflow workflowDefinition,  String workspacePath,  RunStatus status,  DateTime startedAt,  String? workflowId,  DateTime? finishedAt,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _Run():
return $default(_that.id,_that.workflowName,_that.workflowDefinition,_that.workspacePath,_that.status,_that.startedAt,_that.workflowId,_that.finishedAt,_that.errorMessage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workflowName,  Workflow workflowDefinition,  String workspacePath,  RunStatus status,  DateTime startedAt,  String? workflowId,  DateTime? finishedAt,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _Run() when $default != null:
return $default(_that.id,_that.workflowName,_that.workflowDefinition,_that.workspacePath,_that.status,_that.startedAt,_that.workflowId,_that.finishedAt,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Run implements Run {
  const _Run({required this.id, required this.workflowName, required this.workflowDefinition, required this.workspacePath, required this.status, required this.startedAt, this.workflowId, this.finishedAt, this.errorMessage});
  factory _Run.fromJson(Map<String, dynamic> json) => _$RunFromJson(json);

@override final  String id;
@override final  String workflowName;
@override final  Workflow workflowDefinition;
@override final  String workspacePath;
@override final  RunStatus status;
@override final  DateTime startedAt;
@override final  String? workflowId;
@override final  DateTime? finishedAt;
@override final  String? errorMessage;

/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunCopyWith<_Run> get copyWith => __$RunCopyWithImpl<_Run>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Run&&(identical(other.id, id) || other.id == id)&&(identical(other.workflowName, workflowName) || other.workflowName == workflowName)&&(identical(other.workflowDefinition, workflowDefinition) || other.workflowDefinition == workflowDefinition)&&(identical(other.workspacePath, workspacePath) || other.workspacePath == workspacePath)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,workflowName,workflowDefinition,workspacePath,status,startedAt,workflowId,finishedAt,errorMessage);
}

@override
String toString() {
    return 'Run(id: $id, workflowName: $workflowName, workflowDefinition: $workflowDefinition, workspacePath: $workspacePath, status: $status, startedAt: $startedAt, workflowId: $workflowId, finishedAt: $finishedAt, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$RunCopyWith<$Res> implements $RunCopyWith<$Res> {
  factory _$RunCopyWith(_Run value, $Res Function(_Run) _then) = __$RunCopyWithImpl;
@override @useResult
$Res call({
 String id, String workflowName, Workflow workflowDefinition, String workspacePath, RunStatus status, DateTime startedAt, String? workflowId, DateTime? finishedAt, String? errorMessage
});


@override $WorkflowCopyWith<$Res> get workflowDefinition;

}
/// @nodoc
class __$RunCopyWithImpl<$Res>
    implements _$RunCopyWith<$Res> {
  __$RunCopyWithImpl(this._self, this._then);

  final _Run _self;
  final $Res Function(_Run) _then;

/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workflowName = null,Object? workflowDefinition = null,Object? workspacePath = null,Object? status = null,Object? startedAt = null,Object? workflowId = freezed,Object? finishedAt = freezed,Object? errorMessage = freezed,}) {
  return _then(_Run(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workflowName: null == workflowName ? _self.workflowName : workflowName // ignore: cast_nullable_to_non_nullable
as String,workflowDefinition: null == workflowDefinition ? _self.workflowDefinition : workflowDefinition // ignore: cast_nullable_to_non_nullable
as Workflow,workspacePath: null == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RunStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,workflowId: freezed == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Run
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflowDefinition {
  
  return $WorkflowCopyWith<$Res>(_self.workflowDefinition, (value) {
    return _then(_self.copyWith(workflowDefinition: value));
  });
}
}

// dart format on
