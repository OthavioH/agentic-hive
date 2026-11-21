// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_validation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkflowValidationIssue {

 WorkflowValidationSeverity get severity; String get code; String get message; String? get nodeId; String? get edgeId;
/// Create a copy of WorkflowValidationIssue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowValidationIssueCopyWith<WorkflowValidationIssue> get copyWith => _$WorkflowValidationIssueCopyWithImpl<WorkflowValidationIssue>(this as WorkflowValidationIssue, _$identity);

  /// Serializes this WorkflowValidationIssue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowValidationIssue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowValidationIssue&&(identical(other.severity, _this.severity) || other.severity == _this.severity)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.nodeId, _this.nodeId) || other.nodeId == _this.nodeId)&&(identical(other.edgeId, _this.edgeId) || other.edgeId == _this.edgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowValidationIssue;
  return Object.hash(runtimeType,_this.severity,_this.code,_this.message,_this.nodeId,_this.edgeId);
}

@override
String toString() {
  final _this = this as WorkflowValidationIssue;
  return 'WorkflowValidationIssue(severity: ${_this.severity}, code: ${_this.code}, message: ${_this.message}, nodeId: ${_this.nodeId}, edgeId: ${_this.edgeId})';
}


}

/// @nodoc
abstract mixin class $WorkflowValidationIssueCopyWith<$Res>  {
  factory $WorkflowValidationIssueCopyWith(WorkflowValidationIssue value, $Res Function(WorkflowValidationIssue) _then) = _$WorkflowValidationIssueCopyWithImpl;
@useResult
$Res call({
 WorkflowValidationSeverity severity, String code, String message, String? nodeId, String? edgeId
});




}
/// @nodoc
class _$WorkflowValidationIssueCopyWithImpl<$Res>
    implements $WorkflowValidationIssueCopyWith<$Res> {
  _$WorkflowValidationIssueCopyWithImpl(this._self, this._then);

  final WorkflowValidationIssue _self;
  final $Res Function(WorkflowValidationIssue) _then;

/// Create a copy of WorkflowValidationIssue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? severity = null,Object? code = null,Object? message = null,Object? nodeId = freezed,Object? edgeId = freezed,}) {
  return _then(WorkflowValidationIssue(
severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as WorkflowValidationSeverity,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,nodeId: freezed == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String?,edgeId: freezed == edgeId ? _self.edgeId : edgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowValidationIssue].
extension WorkflowValidationIssuePatterns on WorkflowValidationIssue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowValidationIssue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowValidationIssue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowValidationIssue value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowValidationIssue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowValidationIssue value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowValidationIssue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkflowValidationSeverity severity,  String code,  String message,  String? nodeId,  String? edgeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowValidationIssue() when $default != null:
return $default(_that.severity,_that.code,_that.message,_that.nodeId,_that.edgeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkflowValidationSeverity severity,  String code,  String message,  String? nodeId,  String? edgeId)  $default,) {final _that = this;
switch (_that) {
case _WorkflowValidationIssue():
return $default(_that.severity,_that.code,_that.message,_that.nodeId,_that.edgeId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkflowValidationSeverity severity,  String code,  String message,  String? nodeId,  String? edgeId)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowValidationIssue() when $default != null:
return $default(_that.severity,_that.code,_that.message,_that.nodeId,_that.edgeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowValidationIssue implements WorkflowValidationIssue {
  const _WorkflowValidationIssue({required this.severity, required this.code, required this.message, this.nodeId, this.edgeId});
  factory _WorkflowValidationIssue.fromJson(Map<String, dynamic> json) => _$WorkflowValidationIssueFromJson(json);

@override final  WorkflowValidationSeverity severity;
@override final  String code;
@override final  String message;
@override final  String? nodeId;
@override final  String? edgeId;

/// Create a copy of WorkflowValidationIssue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowValidationIssueCopyWith<_WorkflowValidationIssue> get copyWith => __$WorkflowValidationIssueCopyWithImpl<_WorkflowValidationIssue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowValidationIssueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowValidationIssue&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.edgeId, edgeId) || other.edgeId == edgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,severity,code,message,nodeId,edgeId);
}

@override
String toString() {
    return 'WorkflowValidationIssue(severity: $severity, code: $code, message: $message, nodeId: $nodeId, edgeId: $edgeId)';
}


}

/// @nodoc
abstract mixin class _$WorkflowValidationIssueCopyWith<$Res> implements $WorkflowValidationIssueCopyWith<$Res> {
  factory _$WorkflowValidationIssueCopyWith(_WorkflowValidationIssue value, $Res Function(_WorkflowValidationIssue) _then) = __$WorkflowValidationIssueCopyWithImpl;
@override @useResult
$Res call({
 WorkflowValidationSeverity severity, String code, String message, String? nodeId, String? edgeId
});




}
/// @nodoc
class __$WorkflowValidationIssueCopyWithImpl<$Res>
    implements _$WorkflowValidationIssueCopyWith<$Res> {
  __$WorkflowValidationIssueCopyWithImpl(this._self, this._then);

  final _WorkflowValidationIssue _self;
  final $Res Function(_WorkflowValidationIssue) _then;

/// Create a copy of WorkflowValidationIssue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? severity = null,Object? code = null,Object? message = null,Object? nodeId = freezed,Object? edgeId = freezed,}) {
  return _then(_WorkflowValidationIssue(
severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as WorkflowValidationSeverity,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,nodeId: freezed == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String?,edgeId: freezed == edgeId ? _self.edgeId : edgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WorkflowValidationResult {

 bool get isValid; List<WorkflowValidationIssue> get issues;
/// Create a copy of WorkflowValidationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowValidationResultCopyWith<WorkflowValidationResult> get copyWith => _$WorkflowValidationResultCopyWithImpl<WorkflowValidationResult>(this as WorkflowValidationResult, _$identity);

  /// Serializes this WorkflowValidationResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowValidationResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowValidationResult&&(identical(other.isValid, _this.isValid) || other.isValid == _this.isValid)&&const DeepCollectionEquality().equals(other.issues, _this.issues));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowValidationResult;
  return Object.hash(runtimeType,_this.isValid,const DeepCollectionEquality().hash(_this.issues));
}

@override
String toString() {
  final _this = this as WorkflowValidationResult;
  return 'WorkflowValidationResult(isValid: ${_this.isValid}, issues: ${_this.issues})';
}


}

/// @nodoc
abstract mixin class $WorkflowValidationResultCopyWith<$Res>  {
  factory $WorkflowValidationResultCopyWith(WorkflowValidationResult value, $Res Function(WorkflowValidationResult) _then) = _$WorkflowValidationResultCopyWithImpl;
@useResult
$Res call({
 bool isValid, List<WorkflowValidationIssue> issues
});




}
/// @nodoc
class _$WorkflowValidationResultCopyWithImpl<$Res>
    implements $WorkflowValidationResultCopyWith<$Res> {
  _$WorkflowValidationResultCopyWithImpl(this._self, this._then);

  final WorkflowValidationResult _self;
  final $Res Function(WorkflowValidationResult) _then;

/// Create a copy of WorkflowValidationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isValid = null,Object? issues = null,}) {
  return _then(WorkflowValidationResult(
isValid: null == isValid ? _self.isValid : isValid // ignore: cast_nullable_to_non_nullable
as bool,issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as List<WorkflowValidationIssue>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowValidationResult].
extension WorkflowValidationResultPatterns on WorkflowValidationResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowValidationResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowValidationResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowValidationResult value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowValidationResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowValidationResult value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowValidationResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isValid,  List<WorkflowValidationIssue> issues)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowValidationResult() when $default != null:
return $default(_that.isValid,_that.issues);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isValid,  List<WorkflowValidationIssue> issues)  $default,) {final _that = this;
switch (_that) {
case _WorkflowValidationResult():
return $default(_that.isValid,_that.issues);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isValid,  List<WorkflowValidationIssue> issues)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowValidationResult() when $default != null:
return $default(_that.isValid,_that.issues);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowValidationResult implements WorkflowValidationResult {
  const _WorkflowValidationResult({required this.isValid,  List<WorkflowValidationIssue> issues = const <WorkflowValidationIssue>[]}): _issues = issues;
  factory _WorkflowValidationResult.fromJson(Map<String, dynamic> json) => _$WorkflowValidationResultFromJson(json);

@override final  bool isValid;
 final  List<WorkflowValidationIssue> _issues;
@override@JsonKey() List<WorkflowValidationIssue> get issues {
  if (_issues is EqualUnmodifiableListView) return _issues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_issues);
}


/// Create a copy of WorkflowValidationResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowValidationResultCopyWith<_WorkflowValidationResult> get copyWith => __$WorkflowValidationResultCopyWithImpl<_WorkflowValidationResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowValidationResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowValidationResult&&(identical(other.isValid, isValid) || other.isValid == isValid)&&const DeepCollectionEquality().equals(other.issues, _issues));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isValid,const DeepCollectionEquality().hash(_issues));
}

@override
String toString() {
    return 'WorkflowValidationResult(isValid: $isValid, issues: $issues)';
}


}

/// @nodoc
abstract mixin class _$WorkflowValidationResultCopyWith<$Res> implements $WorkflowValidationResultCopyWith<$Res> {
  factory _$WorkflowValidationResultCopyWith(_WorkflowValidationResult value, $Res Function(_WorkflowValidationResult) _then) = __$WorkflowValidationResultCopyWithImpl;
@override @useResult
$Res call({
 bool isValid, List<WorkflowValidationIssue> issues
});




}
/// @nodoc
class __$WorkflowValidationResultCopyWithImpl<$Res>
    implements _$WorkflowValidationResultCopyWith<$Res> {
  __$WorkflowValidationResultCopyWithImpl(this._self, this._then);

  final _WorkflowValidationResult _self;
  final $Res Function(_WorkflowValidationResult) _then;

/// Create a copy of WorkflowValidationResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isValid = null,Object? issues = null,}) {
  return _then(_WorkflowValidationResult(
isValid: null == isValid ? _self.isValid : isValid // ignore: cast_nullable_to_non_nullable
as bool,issues: null == issues ? _self._issues : issues // ignore: cast_nullable_to_non_nullable
as List<WorkflowValidationIssue>,
  ));
}


}

// dart format on
