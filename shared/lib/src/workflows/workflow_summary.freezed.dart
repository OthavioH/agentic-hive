// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkflowSummary {

 String get id; String get name; int get nodeCount; int get edgeCount; bool get hasValidationErrors; DateTime get updatedAt; String? get description;
/// Create a copy of WorkflowSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowSummaryCopyWith<WorkflowSummary> get copyWith => _$WorkflowSummaryCopyWithImpl<WorkflowSummary>(this as WorkflowSummary, _$identity);

  /// Serializes this WorkflowSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.nodeCount, _this.nodeCount) || other.nodeCount == _this.nodeCount)&&(identical(other.edgeCount, _this.edgeCount) || other.edgeCount == _this.edgeCount)&&(identical(other.hasValidationErrors, _this.hasValidationErrors) || other.hasValidationErrors == _this.hasValidationErrors)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowSummary;
  return Object.hash(runtimeType,_this.id,_this.name,_this.nodeCount,_this.edgeCount,_this.hasValidationErrors,_this.updatedAt,_this.description);
}

@override
String toString() {
  final _this = this as WorkflowSummary;
  return 'WorkflowSummary(id: ${_this.id}, name: ${_this.name}, nodeCount: ${_this.nodeCount}, edgeCount: ${_this.edgeCount}, hasValidationErrors: ${_this.hasValidationErrors}, updatedAt: ${_this.updatedAt}, description: ${_this.description})';
}


}

/// @nodoc
abstract mixin class $WorkflowSummaryCopyWith<$Res>  {
  factory $WorkflowSummaryCopyWith(WorkflowSummary value, $Res Function(WorkflowSummary) _then) = _$WorkflowSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, int nodeCount, int edgeCount, bool hasValidationErrors, DateTime updatedAt, String? description
});




}
/// @nodoc
class _$WorkflowSummaryCopyWithImpl<$Res>
    implements $WorkflowSummaryCopyWith<$Res> {
  _$WorkflowSummaryCopyWithImpl(this._self, this._then);

  final WorkflowSummary _self;
  final $Res Function(WorkflowSummary) _then;

/// Create a copy of WorkflowSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nodeCount = null,Object? edgeCount = null,Object? hasValidationErrors = null,Object? updatedAt = null,Object? description = freezed,}) {
  return _then(WorkflowSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nodeCount: null == nodeCount ? _self.nodeCount : nodeCount // ignore: cast_nullable_to_non_nullable
as int,edgeCount: null == edgeCount ? _self.edgeCount : edgeCount // ignore: cast_nullable_to_non_nullable
as int,hasValidationErrors: null == hasValidationErrors ? _self.hasValidationErrors : hasValidationErrors // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowSummary].
extension WorkflowSummaryPatterns on WorkflowSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowSummary value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowSummary value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int nodeCount,  int edgeCount,  bool hasValidationErrors,  DateTime updatedAt,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowSummary() when $default != null:
return $default(_that.id,_that.name,_that.nodeCount,_that.edgeCount,_that.hasValidationErrors,_that.updatedAt,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int nodeCount,  int edgeCount,  bool hasValidationErrors,  DateTime updatedAt,  String? description)  $default,) {final _that = this;
switch (_that) {
case _WorkflowSummary():
return $default(_that.id,_that.name,_that.nodeCount,_that.edgeCount,_that.hasValidationErrors,_that.updatedAt,_that.description);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int nodeCount,  int edgeCount,  bool hasValidationErrors,  DateTime updatedAt,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowSummary() when $default != null:
return $default(_that.id,_that.name,_that.nodeCount,_that.edgeCount,_that.hasValidationErrors,_that.updatedAt,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowSummary implements WorkflowSummary {
  const _WorkflowSummary({required this.id, required this.name, required this.nodeCount, required this.edgeCount, required this.hasValidationErrors, required this.updatedAt, this.description});
  factory _WorkflowSummary.fromJson(Map<String, dynamic> json) => _$WorkflowSummaryFromJson(json);

@override final  String id;
@override final  String name;
@override final  int nodeCount;
@override final  int edgeCount;
@override final  bool hasValidationErrors;
@override final  DateTime updatedAt;
@override final  String? description;

/// Create a copy of WorkflowSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowSummaryCopyWith<_WorkflowSummary> get copyWith => __$WorkflowSummaryCopyWithImpl<_WorkflowSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nodeCount, nodeCount) || other.nodeCount == nodeCount)&&(identical(other.edgeCount, edgeCount) || other.edgeCount == edgeCount)&&(identical(other.hasValidationErrors, hasValidationErrors) || other.hasValidationErrors == hasValidationErrors)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,nodeCount,edgeCount,hasValidationErrors,updatedAt,description);
}

@override
String toString() {
    return 'WorkflowSummary(id: $id, name: $name, nodeCount: $nodeCount, edgeCount: $edgeCount, hasValidationErrors: $hasValidationErrors, updatedAt: $updatedAt, description: $description)';
}


}

/// @nodoc
abstract mixin class _$WorkflowSummaryCopyWith<$Res> implements $WorkflowSummaryCopyWith<$Res> {
  factory _$WorkflowSummaryCopyWith(_WorkflowSummary value, $Res Function(_WorkflowSummary) _then) = __$WorkflowSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int nodeCount, int edgeCount, bool hasValidationErrors, DateTime updatedAt, String? description
});




}
/// @nodoc
class __$WorkflowSummaryCopyWithImpl<$Res>
    implements _$WorkflowSummaryCopyWith<$Res> {
  __$WorkflowSummaryCopyWithImpl(this._self, this._then);

  final _WorkflowSummary _self;
  final $Res Function(_WorkflowSummary) _then;

/// Create a copy of WorkflowSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nodeCount = null,Object? edgeCount = null,Object? hasValidationErrors = null,Object? updatedAt = null,Object? description = freezed,}) {
  return _then(_WorkflowSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nodeCount: null == nodeCount ? _self.nodeCount : nodeCount // ignore: cast_nullable_to_non_nullable
as int,edgeCount: null == edgeCount ? _self.edgeCount : edgeCount // ignore: cast_nullable_to_non_nullable
as int,hasValidationErrors: null == hasValidationErrors ? _self.hasValidationErrors : hasValidationErrors // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
