// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agents_changed_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentsChangedPayload {

 AgentChangeKind get kind; String get id; AgentSummary? get agent;
/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentsChangedPayloadCopyWith<AgentsChangedPayload> get copyWith => _$AgentsChangedPayloadCopyWithImpl<AgentsChangedPayload>(this as AgentsChangedPayload, _$identity);

  /// Serializes this AgentsChangedPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentsChangedPayload;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentsChangedPayload&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.agent, _this.agent) || other.agent == _this.agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentsChangedPayload;
  return Object.hash(runtimeType,_this.kind,_this.id,_this.agent);
}

@override
String toString() {
  final _this = this as AgentsChangedPayload;
  return 'AgentsChangedPayload(kind: ${_this.kind}, id: ${_this.id}, agent: ${_this.agent})';
}


}

/// @nodoc
abstract mixin class $AgentsChangedPayloadCopyWith<$Res>  {
  factory $AgentsChangedPayloadCopyWith(AgentsChangedPayload value, $Res Function(AgentsChangedPayload) _then) = _$AgentsChangedPayloadCopyWithImpl;
@useResult
$Res call({
 AgentChangeKind kind, String id, AgentSummary? agent
});


$AgentSummaryCopyWith<$Res>? get agent;

}
/// @nodoc
class _$AgentsChangedPayloadCopyWithImpl<$Res>
    implements $AgentsChangedPayloadCopyWith<$Res> {
  _$AgentsChangedPayloadCopyWithImpl(this._self, this._then);

  final AgentsChangedPayload _self;
  final $Res Function(AgentsChangedPayload) _then;

/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? id = null,Object? agent = freezed,}) {
  return _then(AgentsChangedPayload(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentChangeKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as AgentSummary?,
  ));
}
/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentSummaryCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $AgentSummaryCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentsChangedPayload].
extension AgentsChangedPayloadPatterns on AgentsChangedPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentsChangedPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentsChangedPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentsChangedPayload value)  $default,){
final _that = this;
switch (_that) {
case _AgentsChangedPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentsChangedPayload value)?  $default,){
final _that = this;
switch (_that) {
case _AgentsChangedPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentChangeKind kind,  String id,  AgentSummary? agent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentsChangedPayload() when $default != null:
return $default(_that.kind,_that.id,_that.agent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentChangeKind kind,  String id,  AgentSummary? agent)  $default,) {final _that = this;
switch (_that) {
case _AgentsChangedPayload():
return $default(_that.kind,_that.id,_that.agent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentChangeKind kind,  String id,  AgentSummary? agent)?  $default,) {final _that = this;
switch (_that) {
case _AgentsChangedPayload() when $default != null:
return $default(_that.kind,_that.id,_that.agent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentsChangedPayload implements AgentsChangedPayload {
  const _AgentsChangedPayload({required this.kind, required this.id, this.agent});
  factory _AgentsChangedPayload.fromJson(Map<String, dynamic> json) => _$AgentsChangedPayloadFromJson(json);

@override final  AgentChangeKind kind;
@override final  String id;
@override final  AgentSummary? agent;

/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentsChangedPayloadCopyWith<_AgentsChangedPayload> get copyWith => __$AgentsChangedPayloadCopyWithImpl<_AgentsChangedPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentsChangedPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentsChangedPayload&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,id,agent);
}

@override
String toString() {
    return 'AgentsChangedPayload(kind: $kind, id: $id, agent: $agent)';
}


}

/// @nodoc
abstract mixin class _$AgentsChangedPayloadCopyWith<$Res> implements $AgentsChangedPayloadCopyWith<$Res> {
  factory _$AgentsChangedPayloadCopyWith(_AgentsChangedPayload value, $Res Function(_AgentsChangedPayload) _then) = __$AgentsChangedPayloadCopyWithImpl;
@override @useResult
$Res call({
 AgentChangeKind kind, String id, AgentSummary? agent
});


@override $AgentSummaryCopyWith<$Res>? get agent;

}
/// @nodoc
class __$AgentsChangedPayloadCopyWithImpl<$Res>
    implements _$AgentsChangedPayloadCopyWith<$Res> {
  __$AgentsChangedPayloadCopyWithImpl(this._self, this._then);

  final _AgentsChangedPayload _self;
  final $Res Function(_AgentsChangedPayload) _then;

/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? id = null,Object? agent = freezed,}) {
  return _then(_AgentsChangedPayload(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentChangeKind,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as AgentSummary?,
  ));
}

/// Create a copy of AgentsChangedPayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentSummaryCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $AgentSummaryCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}

// dart format on
