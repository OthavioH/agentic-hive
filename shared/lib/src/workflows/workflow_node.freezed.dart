// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkflowNode {

 String get id; String get type; String get label; WorkflowPosition get position; JsonMap get config;
/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowNodeCopyWith<WorkflowNode> get copyWith => _$WorkflowNodeCopyWithImpl<WorkflowNode>(this as WorkflowNode, _$identity);

  /// Serializes this WorkflowNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkflowNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowNode&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.position, _this.position) || other.position == _this.position)&&const DeepCollectionEquality().equals(other.config, _this.config));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkflowNode;
  return Object.hash(runtimeType,_this.id,_this.type,_this.label,_this.position,const DeepCollectionEquality().hash(_this.config));
}

@override
String toString() {
  final _this = this as WorkflowNode;
  return 'WorkflowNode(id: ${_this.id}, type: ${_this.type}, label: ${_this.label}, position: ${_this.position}, config: ${_this.config})';
}


}

/// @nodoc
abstract mixin class $WorkflowNodeCopyWith<$Res>  {
  factory $WorkflowNodeCopyWith(WorkflowNode value, $Res Function(WorkflowNode) _then) = _$WorkflowNodeCopyWithImpl;
@useResult
$Res call({
 String id, String type, String label, WorkflowPosition position, JsonMap config
});


$WorkflowPositionCopyWith<$Res> get position;

}
/// @nodoc
class _$WorkflowNodeCopyWithImpl<$Res>
    implements $WorkflowNodeCopyWith<$Res> {
  _$WorkflowNodeCopyWithImpl(this._self, this._then);

  final WorkflowNode _self;
  final $Res Function(WorkflowNode) _then;

/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? label = null,Object? position = null,Object? config = null,}) {
  return _then(WorkflowNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as WorkflowPosition,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}
/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowPositionCopyWith<$Res> get position {
  
  return $WorkflowPositionCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkflowNode].
extension WorkflowNodePatterns on WorkflowNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowNode value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowNode value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String label,  WorkflowPosition position,  JsonMap config)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowNode() when $default != null:
return $default(_that.id,_that.type,_that.label,_that.position,_that.config);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String label,  WorkflowPosition position,  JsonMap config)  $default,) {final _that = this;
switch (_that) {
case _WorkflowNode():
return $default(_that.id,_that.type,_that.label,_that.position,_that.config);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String label,  WorkflowPosition position,  JsonMap config)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowNode() when $default != null:
return $default(_that.id,_that.type,_that.label,_that.position,_that.config);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowNode implements WorkflowNode {
  const _WorkflowNode({required this.id, required this.type, required this.label, required this.position,  JsonMap config = const <String, Object?>{}}): _config = config;
  factory _WorkflowNode.fromJson(Map<String, dynamic> json) => _$WorkflowNodeFromJson(json);

@override final  String id;
@override final  String type;
@override final  String label;
@override final  WorkflowPosition position;
 final  JsonMap _config;
@override@JsonKey() JsonMap get config {
  if (_config is EqualUnmodifiableMapView) return _config;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_config);
}


/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowNodeCopyWith<_WorkflowNode> get copyWith => __$WorkflowNodeCopyWithImpl<_WorkflowNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowNodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowNode&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.label, label) || other.label == label)&&(identical(other.position, position) || other.position == position)&&const DeepCollectionEquality().equals(other.config, _config));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,label,position,const DeepCollectionEquality().hash(_config));
}

@override
String toString() {
    return 'WorkflowNode(id: $id, type: $type, label: $label, position: $position, config: $config)';
}


}

/// @nodoc
abstract mixin class _$WorkflowNodeCopyWith<$Res> implements $WorkflowNodeCopyWith<$Res> {
  factory _$WorkflowNodeCopyWith(_WorkflowNode value, $Res Function(_WorkflowNode) _then) = __$WorkflowNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String label, WorkflowPosition position, JsonMap config
});


@override $WorkflowPositionCopyWith<$Res> get position;

}
/// @nodoc
class __$WorkflowNodeCopyWithImpl<$Res>
    implements _$WorkflowNodeCopyWith<$Res> {
  __$WorkflowNodeCopyWithImpl(this._self, this._then);

  final _WorkflowNode _self;
  final $Res Function(_WorkflowNode) _then;

/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? label = null,Object? position = null,Object? config = null,}) {
  return _then(_WorkflowNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as WorkflowPosition,config: null == config ? _self._config : config // ignore: cast_nullable_to_non_nullable
as JsonMap,
  ));
}

/// Create a copy of WorkflowNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowPositionCopyWith<$Res> get position {
  
  return $WorkflowPositionCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}

// dart format on
