// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentListResponse {

 List<AgentSummary> get agents;
/// Create a copy of AgentListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentListResponseCopyWith<AgentListResponse> get copyWith => _$AgentListResponseCopyWithImpl<AgentListResponse>(this as AgentListResponse, _$identity);

  /// Serializes this AgentListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentListResponse&&const DeepCollectionEquality().equals(other.agents, _this.agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.agents));
}

@override
String toString() {
  final _this = this as AgentListResponse;
  return 'AgentListResponse(agents: ${_this.agents})';
}


}

/// @nodoc
abstract mixin class $AgentListResponseCopyWith<$Res>  {
  factory $AgentListResponseCopyWith(AgentListResponse value, $Res Function(AgentListResponse) _then) = _$AgentListResponseCopyWithImpl;
@useResult
$Res call({
 List<AgentSummary> agents
});




}
/// @nodoc
class _$AgentListResponseCopyWithImpl<$Res>
    implements $AgentListResponseCopyWith<$Res> {
  _$AgentListResponseCopyWithImpl(this._self, this._then);

  final AgentListResponse _self;
  final $Res Function(AgentListResponse) _then;

/// Create a copy of AgentListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agents = null,}) {
  return _then(AgentListResponse(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentListResponse].
extension AgentListResponsePatterns on AgentListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentListResponse value)  $default,){
final _that = this;
switch (_that) {
case _AgentListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AgentListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgentSummary> agents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentListResponse() when $default != null:
return $default(_that.agents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgentSummary> agents)  $default,) {final _that = this;
switch (_that) {
case _AgentListResponse():
return $default(_that.agents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgentSummary> agents)?  $default,) {final _that = this;
switch (_that) {
case _AgentListResponse() when $default != null:
return $default(_that.agents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentListResponse implements AgentListResponse {
  const _AgentListResponse({required  List<AgentSummary> agents}): _agents = agents;
  factory _AgentListResponse.fromJson(Map<String, dynamic> json) => _$AgentListResponseFromJson(json);

 final  List<AgentSummary> _agents;
@override List<AgentSummary> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}


/// Create a copy of AgentListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentListResponseCopyWith<_AgentListResponse> get copyWith => __$AgentListResponseCopyWithImpl<_AgentListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentListResponse&&const DeepCollectionEquality().equals(other.agents, _agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_agents));
}

@override
String toString() {
    return 'AgentListResponse(agents: $agents)';
}


}

/// @nodoc
abstract mixin class _$AgentListResponseCopyWith<$Res> implements $AgentListResponseCopyWith<$Res> {
  factory _$AgentListResponseCopyWith(_AgentListResponse value, $Res Function(_AgentListResponse) _then) = __$AgentListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<AgentSummary> agents
});




}
/// @nodoc
class __$AgentListResponseCopyWithImpl<$Res>
    implements _$AgentListResponseCopyWith<$Res> {
  __$AgentListResponseCopyWithImpl(this._self, this._then);

  final _AgentListResponse _self;
  final $Res Function(_AgentListResponse) _then;

/// Create a copy of AgentListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agents = null,}) {
  return _then(_AgentListResponse(
agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentSummary>,
  ));
}


}

// dart format on
