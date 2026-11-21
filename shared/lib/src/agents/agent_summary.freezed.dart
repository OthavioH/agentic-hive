// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentSummary {

 String get id; String get name; String get contentHash; DateTime get updatedAt; String get description; List<String> get tags; String? get parseError;
/// Create a copy of AgentSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentSummaryCopyWith<AgentSummary> get copyWith => _$AgentSummaryCopyWithImpl<AgentSummary>(this as AgentSummary, _$identity);

  /// Serializes this AgentSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.contentHash, _this.contentHash) || other.contentHash == _this.contentHash)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.parseError, _this.parseError) || other.parseError == _this.parseError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentSummary;
  return Object.hash(runtimeType,_this.id,_this.name,_this.contentHash,_this.updatedAt,_this.description,const DeepCollectionEquality().hash(_this.tags),_this.parseError);
}

@override
String toString() {
  final _this = this as AgentSummary;
  return 'AgentSummary(id: ${_this.id}, name: ${_this.name}, contentHash: ${_this.contentHash}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, tags: ${_this.tags}, parseError: ${_this.parseError})';
}


}

/// @nodoc
abstract mixin class $AgentSummaryCopyWith<$Res>  {
  factory $AgentSummaryCopyWith(AgentSummary value, $Res Function(AgentSummary) _then) = _$AgentSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String contentHash, DateTime updatedAt, String description, List<String> tags, String? parseError
});




}
/// @nodoc
class _$AgentSummaryCopyWithImpl<$Res>
    implements $AgentSummaryCopyWith<$Res> {
  _$AgentSummaryCopyWithImpl(this._self, this._then);

  final AgentSummary _self;
  final $Res Function(AgentSummary) _then;

/// Create a copy of AgentSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? contentHash = null,Object? updatedAt = null,Object? description = null,Object? tags = null,Object? parseError = freezed,}) {
  return _then(AgentSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,contentHash: null == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentSummary].
extension AgentSummaryPatterns on AgentSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentSummary value)  $default,){
final _that = this;
switch (_that) {
case _AgentSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AgentSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  String? parseError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentSummary() when $default != null:
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.parseError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  String? parseError)  $default,) {final _that = this;
switch (_that) {
case _AgentSummary():
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.parseError);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  String? parseError)?  $default,) {final _that = this;
switch (_that) {
case _AgentSummary() when $default != null:
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.parseError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentSummary implements AgentSummary {
  const _AgentSummary({required this.id, required this.name, required this.contentHash, required this.updatedAt, this.description = '',  List<String> tags = const <String>[], this.parseError}): _tags = tags;
  factory _AgentSummary.fromJson(Map<String, dynamic> json) => _$AgentSummaryFromJson(json);

@override final  String id;
@override final  String name;
@override final  String contentHash;
@override final  DateTime updatedAt;
@override@JsonKey() final  String description;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  String? parseError;

/// Create a copy of AgentSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentSummaryCopyWith<_AgentSummary> get copyWith => __$AgentSummaryCopyWithImpl<_AgentSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.contentHash, contentHash) || other.contentHash == contentHash)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.parseError, parseError) || other.parseError == parseError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,contentHash,updatedAt,description,const DeepCollectionEquality().hash(_tags),parseError);
}

@override
String toString() {
    return 'AgentSummary(id: $id, name: $name, contentHash: $contentHash, updatedAt: $updatedAt, description: $description, tags: $tags, parseError: $parseError)';
}


}

/// @nodoc
abstract mixin class _$AgentSummaryCopyWith<$Res> implements $AgentSummaryCopyWith<$Res> {
  factory _$AgentSummaryCopyWith(_AgentSummary value, $Res Function(_AgentSummary) _then) = __$AgentSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String contentHash, DateTime updatedAt, String description, List<String> tags, String? parseError
});




}
/// @nodoc
class __$AgentSummaryCopyWithImpl<$Res>
    implements _$AgentSummaryCopyWith<$Res> {
  __$AgentSummaryCopyWithImpl(this._self, this._then);

  final _AgentSummary _self;
  final $Res Function(_AgentSummary) _then;

/// Create a copy of AgentSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? contentHash = null,Object? updatedAt = null,Object? description = null,Object? tags = null,Object? parseError = freezed,}) {
  return _then(_AgentSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,contentHash: null == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
