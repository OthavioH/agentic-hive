// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentDetail {

 String get id; String get name; String get contentHash; DateTime get updatedAt; String get description; List<String> get tags; List<String> get requiredSkills; List<String> get requiredTools; List<String> get allowedTools; List<String> get deniedTools; String get prompt; String? get parseError; String? get rawContent;
/// Create a copy of AgentDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDetailCopyWith<AgentDetail> get copyWith => _$AgentDetailCopyWithImpl<AgentDetail>(this as AgentDetail, _$identity);

  /// Serializes this AgentDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDetail&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.contentHash, _this.contentHash) || other.contentHash == _this.contentHash)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _this.requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _this.requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _this.allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _this.deniedTools)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.parseError, _this.parseError) || other.parseError == _this.parseError)&&(identical(other.rawContent, _this.rawContent) || other.rawContent == _this.rawContent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentDetail;
  return Object.hash(runtimeType,_this.id,_this.name,_this.contentHash,_this.updatedAt,_this.description,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.requiredSkills),const DeepCollectionEquality().hash(_this.requiredTools),const DeepCollectionEquality().hash(_this.allowedTools),const DeepCollectionEquality().hash(_this.deniedTools),_this.prompt,_this.parseError,_this.rawContent);
}

@override
String toString() {
  final _this = this as AgentDetail;
  return 'AgentDetail(id: ${_this.id}, name: ${_this.name}, contentHash: ${_this.contentHash}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, tags: ${_this.tags}, requiredSkills: ${_this.requiredSkills}, requiredTools: ${_this.requiredTools}, allowedTools: ${_this.allowedTools}, deniedTools: ${_this.deniedTools}, prompt: ${_this.prompt}, parseError: ${_this.parseError}, rawContent: ${_this.rawContent})';
}


}

/// @nodoc
abstract mixin class $AgentDetailCopyWith<$Res>  {
  factory $AgentDetailCopyWith(AgentDetail value, $Res Function(AgentDetail) _then) = _$AgentDetailCopyWithImpl;
@useResult
$Res call({
 String id, String name, String contentHash, DateTime updatedAt, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt, String? parseError, String? rawContent
});




}
/// @nodoc
class _$AgentDetailCopyWithImpl<$Res>
    implements $AgentDetailCopyWith<$Res> {
  _$AgentDetailCopyWithImpl(this._self, this._then);

  final AgentDetail _self;
  final $Res Function(AgentDetail) _then;

/// Create a copy of AgentDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? contentHash = null,Object? updatedAt = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,Object? parseError = freezed,Object? rawContent = freezed,}) {
  return _then(AgentDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,contentHash: null == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self.requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self.requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self.deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,rawContent: freezed == rawContent ? _self.rawContent : rawContent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentDetail].
extension AgentDetailPatterns on AgentDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDetail value)  $default,){
final _that = this;
switch (_that) {
case _AgentDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDetail value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? parseError,  String? rawContent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDetail() when $default != null:
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.parseError,_that.rawContent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? parseError,  String? rawContent)  $default,) {final _that = this;
switch (_that) {
case _AgentDetail():
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.parseError,_that.rawContent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String contentHash,  DateTime updatedAt,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? parseError,  String? rawContent)?  $default,) {final _that = this;
switch (_that) {
case _AgentDetail() when $default != null:
return $default(_that.id,_that.name,_that.contentHash,_that.updatedAt,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.parseError,_that.rawContent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentDetail implements AgentDetail {
  const _AgentDetail({required this.id, required this.name, required this.contentHash, required this.updatedAt, this.description = '',  List<String> tags = const <String>[],  List<String> requiredSkills = const <String>[],  List<String> requiredTools = const <String>[],  List<String> allowedTools = const <String>[],  List<String> deniedTools = const <String>[], this.prompt = '', this.parseError, this.rawContent}): _tags = tags,_requiredSkills = requiredSkills,_requiredTools = requiredTools,_allowedTools = allowedTools,_deniedTools = deniedTools;
  factory _AgentDetail.fromJson(Map<String, dynamic> json) => _$AgentDetailFromJson(json);

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

 final  List<String> _requiredSkills;
@override@JsonKey() List<String> get requiredSkills {
  if (_requiredSkills is EqualUnmodifiableListView) return _requiredSkills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requiredSkills);
}

 final  List<String> _requiredTools;
@override@JsonKey() List<String> get requiredTools {
  if (_requiredTools is EqualUnmodifiableListView) return _requiredTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requiredTools);
}

 final  List<String> _allowedTools;
@override@JsonKey() List<String> get allowedTools {
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowedTools);
}

 final  List<String> _deniedTools;
@override@JsonKey() List<String> get deniedTools {
  if (_deniedTools is EqualUnmodifiableListView) return _deniedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deniedTools);
}

@override@JsonKey() final  String prompt;
@override final  String? parseError;
@override final  String? rawContent;

/// Create a copy of AgentDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDetailCopyWith<_AgentDetail> get copyWith => __$AgentDetailCopyWithImpl<_AgentDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.contentHash, contentHash) || other.contentHash == contentHash)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _deniedTools)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.parseError, parseError) || other.parseError == parseError)&&(identical(other.rawContent, rawContent) || other.rawContent == rawContent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,contentHash,updatedAt,description,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_requiredSkills),const DeepCollectionEquality().hash(_requiredTools),const DeepCollectionEquality().hash(_allowedTools),const DeepCollectionEquality().hash(_deniedTools),prompt,parseError,rawContent);
}

@override
String toString() {
    return 'AgentDetail(id: $id, name: $name, contentHash: $contentHash, updatedAt: $updatedAt, description: $description, tags: $tags, requiredSkills: $requiredSkills, requiredTools: $requiredTools, allowedTools: $allowedTools, deniedTools: $deniedTools, prompt: $prompt, parseError: $parseError, rawContent: $rawContent)';
}


}

/// @nodoc
abstract mixin class _$AgentDetailCopyWith<$Res> implements $AgentDetailCopyWith<$Res> {
  factory _$AgentDetailCopyWith(_AgentDetail value, $Res Function(_AgentDetail) _then) = __$AgentDetailCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String contentHash, DateTime updatedAt, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt, String? parseError, String? rawContent
});




}
/// @nodoc
class __$AgentDetailCopyWithImpl<$Res>
    implements _$AgentDetailCopyWith<$Res> {
  __$AgentDetailCopyWithImpl(this._self, this._then);

  final _AgentDetail _self;
  final $Res Function(_AgentDetail) _then;

/// Create a copy of AgentDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? contentHash = null,Object? updatedAt = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,Object? parseError = freezed,Object? rawContent = freezed,}) {
  return _then(_AgentDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,contentHash: null == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self._requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self._requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self._deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,rawContent: freezed == rawContent ? _self.rawContent : rawContent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
