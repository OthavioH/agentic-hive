// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Workflow {

 String get id; String get name; List<WorkflowNode> get nodes; List<WorkflowEdge> get edges; DateTime get createdAt; DateTime get updatedAt; String? get description; String? get entryNodeId; int get schemaVersion;
/// Create a copy of Workflow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowCopyWith<Workflow> get copyWith => _$WorkflowCopyWithImpl<Workflow>(this as Workflow, _$identity);

  /// Serializes this Workflow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Workflow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workflow&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes)&&const DeepCollectionEquality().equals(other.edges, _this.edges)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.entryNodeId, _this.entryNodeId) || other.entryNodeId == _this.entryNodeId)&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Workflow;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.nodes),const DeepCollectionEquality().hash(_this.edges),_this.createdAt,_this.updatedAt,_this.description,_this.entryNodeId,_this.schemaVersion);
}

@override
String toString() {
  final _this = this as Workflow;
  return 'Workflow(id: ${_this.id}, name: ${_this.name}, nodes: ${_this.nodes}, edges: ${_this.edges}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, entryNodeId: ${_this.entryNodeId}, schemaVersion: ${_this.schemaVersion})';
}


}

/// @nodoc
abstract mixin class $WorkflowCopyWith<$Res>  {
  factory $WorkflowCopyWith(Workflow value, $Res Function(Workflow) _then) = _$WorkflowCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<WorkflowNode> nodes, List<WorkflowEdge> edges, DateTime createdAt, DateTime updatedAt, String? description, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class _$WorkflowCopyWithImpl<$Res>
    implements $WorkflowCopyWith<$Res> {
  _$WorkflowCopyWithImpl(this._self, this._then);

  final Workflow _self;
  final $Res Function(Workflow) _then;

/// Create a copy of Workflow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nodes = null,Object? edges = null,Object? createdAt = null,Object? updatedAt = null,Object? description = freezed,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(Workflow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self.edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Workflow].
extension WorkflowPatterns on Workflow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workflow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workflow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workflow value)  $default,){
final _that = this;
switch (_that) {
case _Workflow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workflow value)?  $default,){
final _that = this;
switch (_that) {
case _Workflow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  DateTime createdAt,  DateTime updatedAt,  String? description,  String? entryNodeId,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workflow() when $default != null:
return $default(_that.id,_that.name,_that.nodes,_that.edges,_that.createdAt,_that.updatedAt,_that.description,_that.entryNodeId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  DateTime createdAt,  DateTime updatedAt,  String? description,  String? entryNodeId,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Workflow():
return $default(_that.id,_that.name,_that.nodes,_that.edges,_that.createdAt,_that.updatedAt,_that.description,_that.entryNodeId,_that.schemaVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  List<WorkflowNode> nodes,  List<WorkflowEdge> edges,  DateTime createdAt,  DateTime updatedAt,  String? description,  String? entryNodeId,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Workflow() when $default != null:
return $default(_that.id,_that.name,_that.nodes,_that.edges,_that.createdAt,_that.updatedAt,_that.description,_that.entryNodeId,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Workflow implements Workflow {
  const _Workflow({required this.id, required this.name, required  List<WorkflowNode> nodes, required  List<WorkflowEdge> edges, required this.createdAt, required this.updatedAt, this.description, this.entryNodeId, this.schemaVersion = 1}): _nodes = nodes,_edges = edges;
  factory _Workflow.fromJson(Map<String, dynamic> json) => _$WorkflowFromJson(json);

@override final  String id;
@override final  String name;
 final  List<WorkflowNode> _nodes;
@override List<WorkflowNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

 final  List<WorkflowEdge> _edges;
@override List<WorkflowEdge> get edges {
  if (_edges is EqualUnmodifiableListView) return _edges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_edges);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? description;
@override final  String? entryNodeId;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Workflow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowCopyWith<_Workflow> get copyWith => __$WorkflowCopyWithImpl<_Workflow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workflow&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.nodes, _nodes)&&const DeepCollectionEquality().equals(other.edges, _edges)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description)&&(identical(other.entryNodeId, entryNodeId) || other.entryNodeId == entryNodeId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_nodes),const DeepCollectionEquality().hash(_edges),createdAt,updatedAt,description,entryNodeId,schemaVersion);
}

@override
String toString() {
    return 'Workflow(id: $id, name: $name, nodes: $nodes, edges: $edges, createdAt: $createdAt, updatedAt: $updatedAt, description: $description, entryNodeId: $entryNodeId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$WorkflowCopyWith<$Res> implements $WorkflowCopyWith<$Res> {
  factory _$WorkflowCopyWith(_Workflow value, $Res Function(_Workflow) _then) = __$WorkflowCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<WorkflowNode> nodes, List<WorkflowEdge> edges, DateTime createdAt, DateTime updatedAt, String? description, String? entryNodeId, int schemaVersion
});




}
/// @nodoc
class __$WorkflowCopyWithImpl<$Res>
    implements _$WorkflowCopyWith<$Res> {
  __$WorkflowCopyWithImpl(this._self, this._then);

  final _Workflow _self;
  final $Res Function(_Workflow) _then;

/// Create a copy of Workflow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nodes = null,Object? edges = null,Object? createdAt = null,Object? updatedAt = null,Object? description = freezed,Object? entryNodeId = freezed,Object? schemaVersion = null,}) {
  return _then(_Workflow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<WorkflowNode>,edges: null == edges ? _self._edges : edges // ignore: cast_nullable_to_non_nullable
as List<WorkflowEdge>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,entryNodeId: freezed == entryNodeId ? _self.entryNodeId : entryNodeId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
