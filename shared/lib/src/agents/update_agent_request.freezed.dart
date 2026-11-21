// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_agent_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UpdateAgentRequest {

 String get name; String get expectedHash; String get description; List<String> get tags; List<String> get requiredSkills; List<String> get requiredTools; List<String> get allowedTools; List<String> get deniedTools; String get prompt;
/// Create a copy of UpdateAgentRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateAgentRequestCopyWith<UpdateAgentRequest> get copyWith => _$UpdateAgentRequestCopyWithImpl<UpdateAgentRequest>(this as UpdateAgentRequest, _$identity);

  /// Serializes this UpdateAgentRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UpdateAgentRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateAgentRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.expectedHash, _this.expectedHash) || other.expectedHash == _this.expectedHash)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _this.requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _this.requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _this.allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _this.deniedTools)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UpdateAgentRequest;
  return Object.hash(runtimeType,_this.name,_this.expectedHash,_this.description,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.requiredSkills),const DeepCollectionEquality().hash(_this.requiredTools),const DeepCollectionEquality().hash(_this.allowedTools),const DeepCollectionEquality().hash(_this.deniedTools),_this.prompt);
}

@override
String toString() {
  final _this = this as UpdateAgentRequest;
  return 'UpdateAgentRequest(name: ${_this.name}, expectedHash: ${_this.expectedHash}, description: ${_this.description}, tags: ${_this.tags}, requiredSkills: ${_this.requiredSkills}, requiredTools: ${_this.requiredTools}, allowedTools: ${_this.allowedTools}, deniedTools: ${_this.deniedTools}, prompt: ${_this.prompt})';
}


}

/// @nodoc
abstract mixin class $UpdateAgentRequestCopyWith<$Res>  {
  factory $UpdateAgentRequestCopyWith(UpdateAgentRequest value, $Res Function(UpdateAgentRequest) _then) = _$UpdateAgentRequestCopyWithImpl;
@useResult
$Res call({
 String name, String expectedHash, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt
});




}
/// @nodoc
class _$UpdateAgentRequestCopyWithImpl<$Res>
    implements $UpdateAgentRequestCopyWith<$Res> {
  _$UpdateAgentRequestCopyWithImpl(this._self, this._then);

  final UpdateAgentRequest _self;
  final $Res Function(UpdateAgentRequest) _then;

/// Create a copy of UpdateAgentRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? expectedHash = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,}) {
  return _then(UpdateAgentRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,expectedHash: null == expectedHash ? _self.expectedHash : expectedHash // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self.requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self.requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self.deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateAgentRequest].
extension UpdateAgentRequestPatterns on UpdateAgentRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateAgentRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateAgentRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateAgentRequest value)  $default,){
final _that = this;
switch (_that) {
case _UpdateAgentRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateAgentRequest value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateAgentRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String expectedHash,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateAgentRequest() when $default != null:
return $default(_that.name,_that.expectedHash,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String expectedHash,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt)  $default,) {final _that = this;
switch (_that) {
case _UpdateAgentRequest():
return $default(_that.name,_that.expectedHash,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String expectedHash,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt)?  $default,) {final _that = this;
switch (_that) {
case _UpdateAgentRequest() when $default != null:
return $default(_that.name,_that.expectedHash,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UpdateAgentRequest implements UpdateAgentRequest {
  const _UpdateAgentRequest({required this.name, required this.expectedHash, this.description = '',  List<String> tags = const <String>[],  List<String> requiredSkills = const <String>[],  List<String> requiredTools = const <String>[],  List<String> allowedTools = const <String>[],  List<String> deniedTools = const <String>[], this.prompt = ''}): _tags = tags,_requiredSkills = requiredSkills,_requiredTools = requiredTools,_allowedTools = allowedTools,_deniedTools = deniedTools;
  factory _UpdateAgentRequest.fromJson(Map<String, dynamic> json) => _$UpdateAgentRequestFromJson(json);

@override final  String name;
@override final  String expectedHash;
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

/// Create a copy of UpdateAgentRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateAgentRequestCopyWith<_UpdateAgentRequest> get copyWith => __$UpdateAgentRequestCopyWithImpl<_UpdateAgentRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateAgentRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateAgentRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.expectedHash, expectedHash) || other.expectedHash == expectedHash)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _deniedTools)&&(identical(other.prompt, prompt) || other.prompt == prompt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,expectedHash,description,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_requiredSkills),const DeepCollectionEquality().hash(_requiredTools),const DeepCollectionEquality().hash(_allowedTools),const DeepCollectionEquality().hash(_deniedTools),prompt);
}

@override
String toString() {
    return 'UpdateAgentRequest(name: $name, expectedHash: $expectedHash, description: $description, tags: $tags, requiredSkills: $requiredSkills, requiredTools: $requiredTools, allowedTools: $allowedTools, deniedTools: $deniedTools, prompt: $prompt)';
}


}

/// @nodoc
abstract mixin class _$UpdateAgentRequestCopyWith<$Res> implements $UpdateAgentRequestCopyWith<$Res> {
  factory _$UpdateAgentRequestCopyWith(_UpdateAgentRequest value, $Res Function(_UpdateAgentRequest) _then) = __$UpdateAgentRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String expectedHash, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt
});




}
/// @nodoc
class __$UpdateAgentRequestCopyWithImpl<$Res>
    implements _$UpdateAgentRequestCopyWith<$Res> {
  __$UpdateAgentRequestCopyWithImpl(this._self, this._then);

  final _UpdateAgentRequest _self;
  final $Res Function(_UpdateAgentRequest) _then;

/// Create a copy of UpdateAgentRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? expectedHash = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,}) {
  return _then(_UpdateAgentRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,expectedHash: null == expectedHash ? _self.expectedHash : expectedHash // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self._requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self._requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self._deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
