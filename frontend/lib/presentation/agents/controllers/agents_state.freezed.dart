// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agents_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AgentDraft implements DiagnosticableTreeMixin {

 String get id; bool get idManuallyEdited; String get name; String get description; List<String> get tags; List<String> get requiredSkills; List<String> get requiredTools; List<String> get allowedTools; List<String> get deniedTools; String get prompt; String? get baseHash; String? get parseError; String? get rawContent;
/// Create a copy of AgentDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDraftCopyWith<AgentDraft> get copyWith => _$AgentDraftCopyWithImpl<AgentDraft>(this as AgentDraft, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as AgentDraft;
  properties
    ..add(DiagnosticsProperty('type', 'AgentDraft'))
    ..add(DiagnosticsProperty('id', _this.id))..add(DiagnosticsProperty('idManuallyEdited', _this.idManuallyEdited))..add(DiagnosticsProperty('name', _this.name))..add(DiagnosticsProperty('description', _this.description))..add(DiagnosticsProperty('tags', _this.tags))..add(DiagnosticsProperty('requiredSkills', _this.requiredSkills))..add(DiagnosticsProperty('requiredTools', _this.requiredTools))..add(DiagnosticsProperty('allowedTools', _this.allowedTools))..add(DiagnosticsProperty('deniedTools', _this.deniedTools))..add(DiagnosticsProperty('prompt', _this.prompt))..add(DiagnosticsProperty('baseHash', _this.baseHash))..add(DiagnosticsProperty('parseError', _this.parseError))..add(DiagnosticsProperty('rawContent', _this.rawContent));
}

@override
bool operator ==(Object other) {
  final _this = this as AgentDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDraft&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.idManuallyEdited, _this.idManuallyEdited) || other.idManuallyEdited == _this.idManuallyEdited)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _this.requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _this.requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _this.allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _this.deniedTools)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.baseHash, _this.baseHash) || other.baseHash == _this.baseHash)&&(identical(other.parseError, _this.parseError) || other.parseError == _this.parseError)&&(identical(other.rawContent, _this.rawContent) || other.rawContent == _this.rawContent));
}


@override
int get hashCode {
  final _this = this as AgentDraft;
  return Object.hash(runtimeType,_this.id,_this.idManuallyEdited,_this.name,_this.description,const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.requiredSkills),const DeepCollectionEquality().hash(_this.requiredTools),const DeepCollectionEquality().hash(_this.allowedTools),const DeepCollectionEquality().hash(_this.deniedTools),_this.prompt,_this.baseHash,_this.parseError,_this.rawContent);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as AgentDraft;
  return 'AgentDraft(id: ${_this.id}, idManuallyEdited: ${_this.idManuallyEdited}, name: ${_this.name}, description: ${_this.description}, tags: ${_this.tags}, requiredSkills: ${_this.requiredSkills}, requiredTools: ${_this.requiredTools}, allowedTools: ${_this.allowedTools}, deniedTools: ${_this.deniedTools}, prompt: ${_this.prompt}, baseHash: ${_this.baseHash}, parseError: ${_this.parseError}, rawContent: ${_this.rawContent})';
}


}

/// @nodoc
abstract mixin class $AgentDraftCopyWith<$Res>  {
  factory $AgentDraftCopyWith(AgentDraft value, $Res Function(AgentDraft) _then) = _$AgentDraftCopyWithImpl;
@useResult
$Res call({
 String id, bool idManuallyEdited, String name, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt, String? baseHash, String? parseError, String? rawContent
});




}
/// @nodoc
class _$AgentDraftCopyWithImpl<$Res>
    implements $AgentDraftCopyWith<$Res> {
  _$AgentDraftCopyWithImpl(this._self, this._then);

  final AgentDraft _self;
  final $Res Function(AgentDraft) _then;

/// Create a copy of AgentDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? idManuallyEdited = null,Object? name = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,Object? baseHash = freezed,Object? parseError = freezed,Object? rawContent = freezed,}) {
  return _then(AgentDraft(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,idManuallyEdited: null == idManuallyEdited ? _self.idManuallyEdited : idManuallyEdited // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self.requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self.requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self.deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,baseHash: freezed == baseHash ? _self.baseHash : baseHash // ignore: cast_nullable_to_non_nullable
as String?,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,rawContent: freezed == rawContent ? _self.rawContent : rawContent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentDraft].
extension AgentDraftPatterns on AgentDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentDraft value)  $default,){
final _that = this;
switch (_that) {
case _AgentDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentDraft value)?  $default,){
final _that = this;
switch (_that) {
case _AgentDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool idManuallyEdited,  String name,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? baseHash,  String? parseError,  String? rawContent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentDraft() when $default != null:
return $default(_that.id,_that.idManuallyEdited,_that.name,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.baseHash,_that.parseError,_that.rawContent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool idManuallyEdited,  String name,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? baseHash,  String? parseError,  String? rawContent)  $default,) {final _that = this;
switch (_that) {
case _AgentDraft():
return $default(_that.id,_that.idManuallyEdited,_that.name,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.baseHash,_that.parseError,_that.rawContent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool idManuallyEdited,  String name,  String description,  List<String> tags,  List<String> requiredSkills,  List<String> requiredTools,  List<String> allowedTools,  List<String> deniedTools,  String prompt,  String? baseHash,  String? parseError,  String? rawContent)?  $default,) {final _that = this;
switch (_that) {
case _AgentDraft() when $default != null:
return $default(_that.id,_that.idManuallyEdited,_that.name,_that.description,_that.tags,_that.requiredSkills,_that.requiredTools,_that.allowedTools,_that.deniedTools,_that.prompt,_that.baseHash,_that.parseError,_that.rawContent);case _:
  return null;

}
}

}

/// @nodoc


class _AgentDraft with DiagnosticableTreeMixin implements AgentDraft {
  const _AgentDraft({this.id = '', this.idManuallyEdited = false, this.name = '', this.description = '',  List<String> tags = const <String>[],  List<String> requiredSkills = const <String>[],  List<String> requiredTools = const <String>[],  List<String> allowedTools = const <String>[],  List<String> deniedTools = const <String>[], this.prompt = '', this.baseHash, this.parseError, this.rawContent}): _tags = tags,_requiredSkills = requiredSkills,_requiredTools = requiredTools,_allowedTools = allowedTools,_deniedTools = deniedTools;
  

@override@JsonKey() final  String id;
@override@JsonKey() final  bool idManuallyEdited;
@override@JsonKey() final  String name;
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
@override final  String? baseHash;
@override final  String? parseError;
@override final  String? rawContent;

/// Create a copy of AgentDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentDraftCopyWith<_AgentDraft> get copyWith => __$AgentDraftCopyWithImpl<_AgentDraft>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AgentDraft'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('idManuallyEdited', idManuallyEdited))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('description', description))..add(DiagnosticsProperty('tags', tags))..add(DiagnosticsProperty('requiredSkills', requiredSkills))..add(DiagnosticsProperty('requiredTools', requiredTools))..add(DiagnosticsProperty('allowedTools', allowedTools))..add(DiagnosticsProperty('deniedTools', deniedTools))..add(DiagnosticsProperty('prompt', prompt))..add(DiagnosticsProperty('baseHash', baseHash))..add(DiagnosticsProperty('parseError', parseError))..add(DiagnosticsProperty('rawContent', rawContent));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentDraft&&(identical(other.id, id) || other.id == id)&&(identical(other.idManuallyEdited, idManuallyEdited) || other.idManuallyEdited == idManuallyEdited)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.requiredSkills, _requiredSkills)&&const DeepCollectionEquality().equals(other.requiredTools, _requiredTools)&&const DeepCollectionEquality().equals(other.allowedTools, _allowedTools)&&const DeepCollectionEquality().equals(other.deniedTools, _deniedTools)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.baseHash, baseHash) || other.baseHash == baseHash)&&(identical(other.parseError, parseError) || other.parseError == parseError)&&(identical(other.rawContent, rawContent) || other.rawContent == rawContent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,idManuallyEdited,name,description,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_requiredSkills),const DeepCollectionEquality().hash(_requiredTools),const DeepCollectionEquality().hash(_allowedTools),const DeepCollectionEquality().hash(_deniedTools),prompt,baseHash,parseError,rawContent);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AgentDraft(id: $id, idManuallyEdited: $idManuallyEdited, name: $name, description: $description, tags: $tags, requiredSkills: $requiredSkills, requiredTools: $requiredTools, allowedTools: $allowedTools, deniedTools: $deniedTools, prompt: $prompt, baseHash: $baseHash, parseError: $parseError, rawContent: $rawContent)';
}


}

/// @nodoc
abstract mixin class _$AgentDraftCopyWith<$Res> implements $AgentDraftCopyWith<$Res> {
  factory _$AgentDraftCopyWith(_AgentDraft value, $Res Function(_AgentDraft) _then) = __$AgentDraftCopyWithImpl;
@override @useResult
$Res call({
 String id, bool idManuallyEdited, String name, String description, List<String> tags, List<String> requiredSkills, List<String> requiredTools, List<String> allowedTools, List<String> deniedTools, String prompt, String? baseHash, String? parseError, String? rawContent
});




}
/// @nodoc
class __$AgentDraftCopyWithImpl<$Res>
    implements _$AgentDraftCopyWith<$Res> {
  __$AgentDraftCopyWithImpl(this._self, this._then);

  final _AgentDraft _self;
  final $Res Function(_AgentDraft) _then;

/// Create a copy of AgentDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? idManuallyEdited = null,Object? name = null,Object? description = null,Object? tags = null,Object? requiredSkills = null,Object? requiredTools = null,Object? allowedTools = null,Object? deniedTools = null,Object? prompt = null,Object? baseHash = freezed,Object? parseError = freezed,Object? rawContent = freezed,}) {
  return _then(_AgentDraft(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,idManuallyEdited: null == idManuallyEdited ? _self.idManuallyEdited : idManuallyEdited // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,requiredSkills: null == requiredSkills ? _self._requiredSkills : requiredSkills // ignore: cast_nullable_to_non_nullable
as List<String>,requiredTools: null == requiredTools ? _self._requiredTools : requiredTools // ignore: cast_nullable_to_non_nullable
as List<String>,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,deniedTools: null == deniedTools ? _self._deniedTools : deniedTools // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,baseHash: freezed == baseHash ? _self.baseHash : baseHash // ignore: cast_nullable_to_non_nullable
as String?,parseError: freezed == parseError ? _self.parseError : parseError // ignore: cast_nullable_to_non_nullable
as String?,rawContent: freezed == rawContent ? _self.rawContent : rawContent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
