// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateWorkflowRequest {

 String get name; String? get description; List<WorkflowNode> get nodes; List<WorkflowEdge> get edges; String? get entryNodeId; int get schemaVersion;
/// Create a copy of CreateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateWorkflowRequestCopyWith<CreateWorkflowRequest> get copyWith => _$CreateWorkflowRequestCopyWithImpl<CreateWorkflowRequest>(this as CreateWorkflowRequest, _$identity);

  /// Serializes this CreateWorkflowRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CreateWorkflowRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateWorkflowRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes)&&const DeepCollectionEquality().equals(other.edges, _this.edges)&&(identical(other.entryNodeId, _this.entryNodeId) || other.entryNodeId == _this.entryNodeId)&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CreateWorkflowRequest;
  return Object.hash(runtimeType,_this.name,_this.description,const DeepCollectionEquality().hash(_this.nodes),const DeepCollectionEquality().hash(_this.edges),_this.entryNodeId,_this.schemaVersion);
}

@override
String toString() {
  final _this = this as CreateWorkflowRequest;
  return 'CreateWorkflowRequest(name: ${_this.name}, description: ${_this.description}, nodes: ${_this.nodes}, edges: ${_this.edges}, entryNodeId: ${_this.entryNodeId}, schemaVersion: ${_this.schemaVersion})';
}


}

/// @nodoc
abstract mixin class $CreateWorkflowRequestCopyWith<$Res>  {
  factory $CreateWorkflowRequestCopyWith(CreateWorkflowRequest value, $Res Function(CreateWorkflowRequest) _then) = _$CreateWorkflowRequestCopyWithImpl;
@useResult
$Res call({
 String name, String? description, List<WorkflowNode> nodes, List<WorkflowEdge> edges, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class _$CreateWorkflowRequestCopyWithImpl<$Res>
    implements $CreateWorkflowRequestCopyWith<$Res> {
  _$CreateWorkflowRequestCopyWithImpl(this._self, this._then);

  final CreateWorkflowRequest _self;
  final $Res Function(CreateWorkflowRequest) _then;

/// Create a copy of CreateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? nodes = null,Object? edges = null,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(CreateWorkflowRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self.edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateWorkflowRequest].
extension CreateWorkflowRequestPatterns on CreateWorkflowRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateWorkflowRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateWorkflowRequest value)  $default,){
final _that = this;
switch (_that) {
case _CreateWorkflowRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateWorkflowRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CreateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateWorkflowRequest() when $default != null:
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _CreateWorkflowRequest():
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _CreateWorkflowRequest() when $default != null:
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateWorkflowRequest implements CreateWorkflowRequest {
  const _CreateWorkflowRequest({required this.name, this.description,  List<WorkflowNode> nodes = const <WorkflowNode>[],  List<WorkflowEdge> edges = const <WorkflowEdge>[], this.entryNodeId, this.schemaVersion = 1}): _nodes = nodes,_edges = edges;
  factory _CreateWorkflowRequest.fromJson(Map<String, dynamic> json) => _$CreateWorkflowRequestFromJson(json);

@override final  String name;
@override final  String? description;
 final  List<WorkflowNode> _nodes;
@override@JsonKey() List<WorkflowNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

 final  List<WorkflowEdge> _edges;
@override@JsonKey() List<WorkflowEdge> get edges {
  if (_edges is EqualUnmodifiableListView) return _edges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_edges);
}

@override final  String? entryNodeId;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of CreateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateWorkflowRequestCopyWith<_CreateWorkflowRequest> get copyWith => __$CreateWorkflowRequestCopyWithImpl<_CreateWorkflowRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateWorkflowRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateWorkflowRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.nodes, _nodes)&&const DeepCollectionEquality().equals(other.edges, _edges)&&(identical(other.entryNodeId, entryNodeId) || other.entryNodeId == entryNodeId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_nodes),const DeepCollectionEquality().hash(_edges),entryNodeId,schemaVersion);
}

@override
String toString() {
    return 'CreateWorkflowRequest(name: $name, description: $description, nodes: $nodes, edges: $edges, entryNodeId: $entryNodeId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$CreateWorkflowRequestCopyWith<$Res> implements $CreateWorkflowRequestCopyWith<$Res> {
  factory _$CreateWorkflowRequestCopyWith(_CreateWorkflowRequest value, $Res Function(_CreateWorkflowRequest) _then) = __$CreateWorkflowRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, List<WorkflowNode> nodes, List<WorkflowEdge> edges, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class __$CreateWorkflowRequestCopyWithImpl<$Res>
    implements _$CreateWorkflowRequestCopyWith<$Res> {
  __$CreateWorkflowRequestCopyWithImpl(this._self, this._then);

  final _CreateWorkflowRequest _self;
  final $Res Function(_CreateWorkflowRequest) _then;

/// Create a copy of CreateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? nodes = null,Object? edges = null,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(_CreateWorkflowRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self._edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UpdateWorkflowRequest {

 String get name; String? get description; List<WorkflowNode> get nodes; List<WorkflowEdge> get edges; String? get entryNodeId; int get schemaVersion;
/// Create a copy of UpdateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateWorkflowRequestCopyWith<UpdateWorkflowRequest> get copyWith => _$UpdateWorkflowRequestCopyWithImpl<UpdateWorkflowRequest>(this as UpdateWorkflowRequest, _$identity);

  /// Serializes this UpdateWorkflowRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UpdateWorkflowRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateWorkflowRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes)&&const DeepCollectionEquality().equals(other.edges, _this.edges)&&(identical(other.entryNodeId, _this.entryNodeId) || other.entryNodeId == _this.entryNodeId)&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UpdateWorkflowRequest;
  return Object.hash(runtimeType,_this.name,_this.description,const DeepCollectionEquality().hash(_this.nodes),const DeepCollectionEquality().hash(_this.edges),_this.entryNodeId,_this.schemaVersion);
}

@override
String toString() {
  final _this = this as UpdateWorkflowRequest;
  return 'UpdateWorkflowRequest(name: ${_this.name}, description: ${_this.description}, nodes: ${_this.nodes}, edges: ${_this.edges}, entryNodeId: ${_this.entryNodeId}, schemaVersion: ${_this.schemaVersion})';
}


}

/// @nodoc
abstract mixin class $UpdateWorkflowRequestCopyWith<$Res>  {
  factory $UpdateWorkflowRequestCopyWith(UpdateWorkflowRequest value, $Res Function(UpdateWorkflowRequest) _then) = _$UpdateWorkflowRequestCopyWithImpl;
@useResult
$Res call({
 String name, String? description, List<WorkflowNode> nodes, List<WorkflowEdge> edges, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class _$UpdateWorkflowRequestCopyWithImpl<$Res>
    implements $UpdateWorkflowRequestCopyWith<$Res> {
  _$UpdateWorkflowRequestCopyWithImpl(this._self, this._then);

  final UpdateWorkflowRequest _self;
  final $Res Function(UpdateWorkflowRequest) _then;

/// Create a copy of UpdateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? nodes = null,Object? edges = null,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(UpdateWorkflowRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self.edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateWorkflowRequest].
extension UpdateWorkflowRequestPatterns on UpdateWorkflowRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateWorkflowRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateWorkflowRequest value)  $default,){
final _that = this;
switch (_that) {
case _UpdateWorkflowRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateWorkflowRequest value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateWorkflowRequest() when $default != null:
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _UpdateWorkflowRequest():
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  String? entryNodeId,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _UpdateWorkflowRequest() when $default != null:
return $default(_that.name,_that.description,_that.nodes,_that.edges,_that.entryNodeId,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UpdateWorkflowRequest implements UpdateWorkflowRequest {
  const _UpdateWorkflowRequest({required this.name, this.description,  List<WorkflowNode> nodes = const <WorkflowNode>[],  List<WorkflowEdge> edges = const <WorkflowEdge>[], this.entryNodeId, this.schemaVersion = 1}): _nodes = nodes,_edges = edges;
  factory _UpdateWorkflowRequest.fromJson(Map<String, dynamic> json) => _$UpdateWorkflowRequestFromJson(json);

@override final  String name;
@override final  String? description;
 final  List<WorkflowNode> _nodes;
@override@JsonKey() List<WorkflowNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

 final  List<WorkflowEdge> _edges;
@override@JsonKey() List<WorkflowEdge> get edges {
  if (_edges is EqualUnmodifiableListView) return _edges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_edges);
}

@override final  String? entryNodeId;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of UpdateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateWorkflowRequestCopyWith<_UpdateWorkflowRequest> get copyWith => __$UpdateWorkflowRequestCopyWithImpl<_UpdateWorkflowRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateWorkflowRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateWorkflowRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.nodes, _nodes)&&const DeepCollectionEquality().equals(other.edges, _edges)&&(identical(other.entryNodeId, entryNodeId) || other.entryNodeId == entryNodeId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_nodes),const DeepCollectionEquality().hash(_edges),entryNodeId,schemaVersion);
}

@override
String toString() {
    return 'UpdateWorkflowRequest(name: $name, description: $description, nodes: $nodes, edges: $edges, entryNodeId: $entryNodeId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$UpdateWorkflowRequestCopyWith<$Res> implements $UpdateWorkflowRequestCopyWith<$Res> {
  factory _$UpdateWorkflowRequestCopyWith(_UpdateWorkflowRequest value, $Res Function(_UpdateWorkflowRequest) _then) = __$UpdateWorkflowRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, List<WorkflowNode> nodes, List<WorkflowEdge> edges, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class __$UpdateWorkflowRequestCopyWithImpl<$Res>
    implements _$UpdateWorkflowRequestCopyWith<$Res> {
  __$UpdateWorkflowRequestCopyWithImpl(this._self, this._then);

  final _UpdateWorkflowRequest _self;
  final $Res Function(_UpdateWorkflowRequest) _then;

/// Create a copy of UpdateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? nodes = null,Object? edges = null,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(_UpdateWorkflowRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self._edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DuplicateWorkflowRequest {

 String? get name;
/// Create a copy of DuplicateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DuplicateWorkflowRequestCopyWith<DuplicateWorkflowRequest> get copyWith => _$DuplicateWorkflowRequestCopyWithImpl<DuplicateWorkflowRequest>(this as DuplicateWorkflowRequest, _$identity);

  /// Serializes this DuplicateWorkflowRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DuplicateWorkflowRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DuplicateWorkflowRequest&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DuplicateWorkflowRequest;
  return Object.hash(runtimeType,_this.name);
}

@override
String toString() {
  final _this = this as DuplicateWorkflowRequest;
  return 'DuplicateWorkflowRequest(name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $DuplicateWorkflowRequestCopyWith<$Res>  {
  factory $DuplicateWorkflowRequestCopyWith(DuplicateWorkflowRequest value, $Res Function(DuplicateWorkflowRequest) _then) = _$DuplicateWorkflowRequestCopyWithImpl;
@useResult
$Res call({
 String? name
});




}
/// @nodoc
class _$DuplicateWorkflowRequestCopyWithImpl<$Res>
    implements $DuplicateWorkflowRequestCopyWith<$Res> {
  _$DuplicateWorkflowRequestCopyWithImpl(this._self, this._then);

  final DuplicateWorkflowRequest _self;
  final $Res Function(DuplicateWorkflowRequest) _then;

/// Create a copy of DuplicateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,}) {
  return _then(DuplicateWorkflowRequest(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DuplicateWorkflowRequest].
extension DuplicateWorkflowRequestPatterns on DuplicateWorkflowRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DuplicateWorkflowRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DuplicateWorkflowRequest value)  $default,){
final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DuplicateWorkflowRequest value)?  $default,){
final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest() when $default != null:
return $default(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name)  $default,) {final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest():
return $default(_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name)?  $default,) {final _that = this;
switch (_that) {
case _DuplicateWorkflowRequest() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DuplicateWorkflowRequest implements DuplicateWorkflowRequest {
  const _DuplicateWorkflowRequest({this.name});
  factory _DuplicateWorkflowRequest.fromJson(Map<String, dynamic> json) => _$DuplicateWorkflowRequestFromJson(json);

@override final  String? name;

/// Create a copy of DuplicateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DuplicateWorkflowRequestCopyWith<_DuplicateWorkflowRequest> get copyWith => __$DuplicateWorkflowRequestCopyWithImpl<_DuplicateWorkflowRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DuplicateWorkflowRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DuplicateWorkflowRequest&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'DuplicateWorkflowRequest(name: $name)';
}


}

/// @nodoc
abstract mixin class _$DuplicateWorkflowRequestCopyWith<$Res> implements $DuplicateWorkflowRequestCopyWith<$Res> {
  factory _$DuplicateWorkflowRequestCopyWith(_DuplicateWorkflowRequest value, $Res Function(_DuplicateWorkflowRequest) _then) = __$DuplicateWorkflowRequestCopyWithImpl;
@override @useResult
$Res call({
 String? name
});




}
/// @nodoc
class __$DuplicateWorkflowRequestCopyWithImpl<$Res>
    implements _$DuplicateWorkflowRequestCopyWith<$Res> {
  __$DuplicateWorkflowRequestCopyWithImpl(this._self, this._then);

  final _DuplicateWorkflowRequest _self;
  final $Res Function(_DuplicateWorkflowRequest) _then;

/// Create a copy of DuplicateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,}) {
  return _then(_DuplicateWorkflowRequest(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ValidateWorkflowRequest {

 Workflow get workflow;
/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidateWorkflowRequestCopyWith<ValidateWorkflowRequest> get copyWith => _$ValidateWorkflowRequestCopyWithImpl<ValidateWorkflowRequest>(this as ValidateWorkflowRequest, _$identity);

  /// Serializes this ValidateWorkflowRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ValidateWorkflowRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidateWorkflowRequest&&(identical(other.workflow, _this.workflow) || other.workflow == _this.workflow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ValidateWorkflowRequest;
  return Object.hash(runtimeType,_this.workflow);
}

@override
String toString() {
  final _this = this as ValidateWorkflowRequest;
  return 'ValidateWorkflowRequest(workflow: ${_this.workflow})';
}


}

/// @nodoc
abstract mixin class $ValidateWorkflowRequestCopyWith<$Res>  {
  factory $ValidateWorkflowRequestCopyWith(ValidateWorkflowRequest value, $Res Function(ValidateWorkflowRequest) _then) = _$ValidateWorkflowRequestCopyWithImpl;
@useResult
$Res call({
 Workflow workflow
});


$WorkflowCopyWith<$Res> get workflow;

}
/// @nodoc
class _$ValidateWorkflowRequestCopyWithImpl<$Res>
    implements $ValidateWorkflowRequestCopyWith<$Res> {
  _$ValidateWorkflowRequestCopyWithImpl(this._self, this._then);

  final ValidateWorkflowRequest _self;
  final $Res Function(ValidateWorkflowRequest) _then;

/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workflow = null,}) {
  return _then(ValidateWorkflowRequest(
workflow: null == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as Workflow,
  ));
}
/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflow {
  
  return $WorkflowCopyWith<$Res>(_self.workflow, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}
}


/// Adds pattern-matching-related methods to [ValidateWorkflowRequest].
extension ValidateWorkflowRequestPatterns on ValidateWorkflowRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidateWorkflowRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidateWorkflowRequest value)  $default,){
final _that = this;
switch (_that) {
case _ValidateWorkflowRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidateWorkflowRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ValidateWorkflowRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Workflow workflow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidateWorkflowRequest() when $default != null:
return $default(_that.workflow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Workflow workflow)  $default,) {final _that = this;
switch (_that) {
case _ValidateWorkflowRequest():
return $default(_that.workflow);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Workflow workflow)?  $default,) {final _that = this;
switch (_that) {
case _ValidateWorkflowRequest() when $default != null:
return $default(_that.workflow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ValidateWorkflowRequest implements ValidateWorkflowRequest {
  const _ValidateWorkflowRequest({required this.workflow});
  factory _ValidateWorkflowRequest.fromJson(Map<String, dynamic> json) => _$ValidateWorkflowRequestFromJson(json);

@override final  Workflow workflow;

/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidateWorkflowRequestCopyWith<_ValidateWorkflowRequest> get copyWith => __$ValidateWorkflowRequestCopyWithImpl<_ValidateWorkflowRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ValidateWorkflowRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidateWorkflowRequest&&(identical(other.workflow, workflow) || other.workflow == workflow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,workflow);
}

@override
String toString() {
    return 'ValidateWorkflowRequest(workflow: $workflow)';
}


}

/// @nodoc
abstract mixin class _$ValidateWorkflowRequestCopyWith<$Res> implements $ValidateWorkflowRequestCopyWith<$Res> {
  factory _$ValidateWorkflowRequestCopyWith(_ValidateWorkflowRequest value, $Res Function(_ValidateWorkflowRequest) _then) = __$ValidateWorkflowRequestCopyWithImpl;
@override @useResult
$Res call({
 Workflow workflow
});


@override $WorkflowCopyWith<$Res> get workflow;

}
/// @nodoc
class __$ValidateWorkflowRequestCopyWithImpl<$Res>
    implements _$ValidateWorkflowRequestCopyWith<$Res> {
  __$ValidateWorkflowRequestCopyWithImpl(this._self, this._then);

  final _ValidateWorkflowRequest _self;
  final $Res Function(_ValidateWorkflowRequest) _then;

/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workflow = null,}) {
  return _then(_ValidateWorkflowRequest(
workflow: null == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as Workflow,
  ));
}

/// Create a copy of ValidateWorkflowRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflow {
  
  return $WorkflowCopyWith<$Res>(_self.workflow, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}
}


/// @nodoc
mixin _$WorkflowListResponse {

 List<WorkflowSummary> get workflows;
/// Create a copy of WorkflowListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowListResponseCopyWith<WorkflowListResponse> get copyWith => _$WorkflowListResponseCopyWithImpl<WorkflowListResponse>(this as WorkflowListResponse, _$identity);

  /// Serializes this WorkflowListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowListResponse&&const DeepCollectionEquality().equals(other.workflows, _this.workflows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.workflows));
}

@override
String toString() {
  final _this = this as WorkflowListResponse;
  return 'WorkflowListResponse(workflows: ${_this.workflows})';
}


}

/// @nodoc
abstract mixin class $WorkflowListResponseCopyWith<$Res>  {
  factory $WorkflowListResponseCopyWith(WorkflowListResponse value, $Res Function(WorkflowListResponse) _then) = _$WorkflowListResponseCopyWithImpl;
@useResult
$Res call({
 List<WorkflowSummary> workflows
});




}
/// @nodoc
class _$WorkflowListResponseCopyWithImpl<$Res>
    implements $WorkflowListResponseCopyWith<$Res> {
  _$WorkflowListResponseCopyWithImpl(this._self, this._then);

  final WorkflowListResponse _self;
  final $Res Function(WorkflowListResponse) _then;

/// Create a copy of WorkflowListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workflows = null,}) {
  return _then(WorkflowListResponse(
workflows: null == workflows ? _self.workflows : workflows // ignore: cast_nullable_to_non_nullable
as List<WorkflowSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowListResponse].
extension WorkflowListResponsePatterns on WorkflowListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowListResponse value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<WorkflowSummary> workflows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowListResponse() when $default != null:
return $default(_that.workflows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<WorkflowSummary> workflows)  $default,) {final _that = this;
switch (_that) {
case _WorkflowListResponse():
return $default(_that.workflows);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<WorkflowSummary> workflows)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowListResponse() when $default != null:
return $default(_that.workflows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowListResponse implements WorkflowListResponse {
  const _WorkflowListResponse({required  List<WorkflowSummary> workflows}): _workflows = workflows;
  factory _WorkflowListResponse.fromJson(Map<String, dynamic> json) => _$WorkflowListResponseFromJson(json);

 final  List<WorkflowSummary> _workflows;
@override List<WorkflowSummary> get workflows {
  if (_workflows is EqualUnmodifiableListView) return _workflows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workflows);
}


/// Create a copy of WorkflowListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowListResponseCopyWith<_WorkflowListResponse> get copyWith => __$WorkflowListResponseCopyWithImpl<_WorkflowListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowListResponse&&const DeepCollectionEquality().equals(other.workflows, _workflows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_workflows));
}

@override
String toString() {
    return 'WorkflowListResponse(workflows: $workflows)';
}


}

/// @nodoc
abstract mixin class _$WorkflowListResponseCopyWith<$Res> implements $WorkflowListResponseCopyWith<$Res> {
  factory _$WorkflowListResponseCopyWith(_WorkflowListResponse value, $Res Function(_WorkflowListResponse) _then) = __$WorkflowListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<WorkflowSummary> workflows
});




}
/// @nodoc
class __$WorkflowListResponseCopyWithImpl<$Res>
    implements _$WorkflowListResponseCopyWith<$Res> {
  __$WorkflowListResponseCopyWithImpl(this._self, this._then);

  final _WorkflowListResponse _self;
  final $Res Function(_WorkflowListResponse) _then;

/// Create a copy of WorkflowListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workflows = null,}) {
  return _then(_WorkflowListResponse(
workflows: null == workflows ? _self._workflows : workflows // ignore: cast_nullable_to_non_nullable
as List<WorkflowSummary>,
  ));
}


}


/// @nodoc
mixin _$WorkflowResponse {

 Workflow get workflow; WorkflowValidationResult get validation;
/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowResponseCopyWith<WorkflowResponse> get copyWith => _$WorkflowResponseCopyWithImpl<WorkflowResponse>(this as WorkflowResponse, _$identity);

  /// Serializes this WorkflowResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowResponse&&(identical(other.workflow, _this.workflow) || other.workflow == _this.workflow)&&(identical(other.validation, _this.validation) || other.validation == _this.validation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowResponse;
  return Object.hash(runtimeType,_this.workflow,_this.validation);
}

@override
String toString() {
  final _this = this as WorkflowResponse;
  return 'WorkflowResponse(workflow: ${_this.workflow}, validation: ${_this.validation})';
}


}

/// @nodoc
abstract mixin class $WorkflowResponseCopyWith<$Res>  {
  factory $WorkflowResponseCopyWith(WorkflowResponse value, $Res Function(WorkflowResponse) _then) = _$WorkflowResponseCopyWithImpl;
@useResult
$Res call({
 Workflow workflow, WorkflowValidationResult validation
});


$WorkflowCopyWith<$Res> get workflow;$WorkflowValidationResultCopyWith<$Res> get validation;

}
/// @nodoc
class _$WorkflowResponseCopyWithImpl<$Res>
    implements $WorkflowResponseCopyWith<$Res> {
  _$WorkflowResponseCopyWithImpl(this._self, this._then);

  final WorkflowResponse _self;
  final $Res Function(WorkflowResponse) _then;

/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workflow = null,Object? validation = null,}) {
  return _then(WorkflowResponse(
workflow: null == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as Workflow,validation: null == validation ? _self.validation : validation // ignore: cast_nullable_to_non_nullable
as WorkflowValidationResult,
  ));
}
/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflow {
  
  return $WorkflowCopyWith<$Res>(_self.workflow, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowValidationResultCopyWith<$Res> get validation {
  
  return $WorkflowValidationResultCopyWith<$Res>(_self.validation, (value) {
    return _then(_self.copyWith(validation: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkflowResponse].
extension WorkflowResponsePatterns on WorkflowResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowResponse value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowResponse value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Workflow workflow,  WorkflowValidationResult validation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowResponse() when $default != null:
return $default(_that.workflow,_that.validation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Workflow workflow,  WorkflowValidationResult validation)  $default,) {final _that = this;
switch (_that) {
case _WorkflowResponse():
return $default(_that.workflow,_that.validation);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Workflow workflow,  WorkflowValidationResult validation)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowResponse() when $default != null:
return $default(_that.workflow,_that.validation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowResponse implements WorkflowResponse {
  const _WorkflowResponse({required this.workflow, required this.validation});
  factory _WorkflowResponse.fromJson(Map<String, dynamic> json) => _$WorkflowResponseFromJson(json);

@override final  Workflow workflow;
@override final  WorkflowValidationResult validation;

/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowResponseCopyWith<_WorkflowResponse> get copyWith => __$WorkflowResponseCopyWithImpl<_WorkflowResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowResponse&&(identical(other.workflow, workflow) || other.workflow == workflow)&&(identical(other.validation, validation) || other.validation == validation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,workflow,validation);
}

@override
String toString() {
    return 'WorkflowResponse(workflow: $workflow, validation: $validation)';
}


}

/// @nodoc
abstract mixin class _$WorkflowResponseCopyWith<$Res> implements $WorkflowResponseCopyWith<$Res> {
  factory _$WorkflowResponseCopyWith(_WorkflowResponse value, $Res Function(_WorkflowResponse) _then) = __$WorkflowResponseCopyWithImpl;
@override @useResult
$Res call({
 Workflow workflow, WorkflowValidationResult validation
});


@override $WorkflowCopyWith<$Res> get workflow;@override $WorkflowValidationResultCopyWith<$Res> get validation;

}
/// @nodoc
class __$WorkflowResponseCopyWithImpl<$Res>
    implements _$WorkflowResponseCopyWith<$Res> {
  __$WorkflowResponseCopyWithImpl(this._self, this._then);

  final _WorkflowResponse _self;
  final $Res Function(_WorkflowResponse) _then;

/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workflow = null,Object? validation = null,}) {
  return _then(_WorkflowResponse(
workflow: null == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as Workflow,validation: null == validation ? _self.validation : validation // ignore: cast_nullable_to_non_nullable
as WorkflowValidationResult,
  ));
}

/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowCopyWith<$Res> get workflow {
  
  return $WorkflowCopyWith<$Res>(_self.workflow, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}/// Create a copy of WorkflowResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowValidationResultCopyWith<$Res> get validation {
  
  return $WorkflowValidationResultCopyWith<$Res>(_self.validation, (value) {
    return _then(_self.copyWith(validation: value));
  });
}
}

// dart format on
