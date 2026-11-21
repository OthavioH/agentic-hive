// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RunsListResponse {

 List<RunSummary> get items; int get total;
/// Create a copy of RunsListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunsListResponseCopyWith<RunsListResponse> get copyWith => _$RunsListResponseCopyWithImpl<RunsListResponse>(this as RunsListResponse, _$identity);

  /// Serializes this RunsListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunsListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunsListResponse&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.total, _this.total) || other.total == _this.total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunsListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.total);
}

@override
String toString() {
  final _this = this as RunsListResponse;
  return 'RunsListResponse(items: ${_this.items}, total: ${_this.total})';
}


}

/// @nodoc
abstract mixin class $RunsListResponseCopyWith<$Res>  {
  factory $RunsListResponseCopyWith(RunsListResponse value, $Res Function(RunsListResponse) _then) = _$RunsListResponseCopyWithImpl;
@useResult
$Res call({
 List<RunSummary> items, int total
});




}
/// @nodoc
class _$RunsListResponseCopyWithImpl<$Res>
    implements $RunsListResponseCopyWith<$Res> {
  _$RunsListResponseCopyWithImpl(this._self, this._then);

  final RunsListResponse _self;
  final $Res Function(RunsListResponse) _then;

/// Create a copy of RunsListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,}) {
  return _then(RunsListResponse(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<RunSummary>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RunsListResponse].
extension RunsListResponsePatterns on RunsListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunsListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunsListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunsListResponse value)  $default,){
final _that = this;
switch (_that) {
case _RunsListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunsListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RunsListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RunSummary> items,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunsListResponse() when $default != null:
return $default(_that.items,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RunSummary> items,  int total)  $default,) {final _that = this;
switch (_that) {
case _RunsListResponse():
return $default(_that.items,_that.total);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RunSummary> items,  int total)?  $default,) {final _that = this;
switch (_that) {
case _RunsListResponse() when $default != null:
return $default(_that.items,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunsListResponse implements RunsListResponse {
  const _RunsListResponse({required  List<RunSummary> items, required this.total}): _items = items;
  factory _RunsListResponse.fromJson(Map<String, dynamic> json) => _$RunsListResponseFromJson(json);

 final  List<RunSummary> _items;
@override List<RunSummary> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int total;

/// Create a copy of RunsListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunsListResponseCopyWith<_RunsListResponse> get copyWith => __$RunsListResponseCopyWithImpl<_RunsListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunsListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunsListResponse&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total);
}

@override
String toString() {
    return 'RunsListResponse(items: $items, total: $total)';
}


}

/// @nodoc
abstract mixin class _$RunsListResponseCopyWith<$Res> implements $RunsListResponseCopyWith<$Res> {
  factory _$RunsListResponseCopyWith(_RunsListResponse value, $Res Function(_RunsListResponse) _then) = __$RunsListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<RunSummary> items, int total
});




}
/// @nodoc
class __$RunsListResponseCopyWithImpl<$Res>
    implements _$RunsListResponseCopyWith<$Res> {
  __$RunsListResponseCopyWithImpl(this._self, this._then);

  final _RunsListResponse _self;
  final $Res Function(_RunsListResponse) _then;

/// Create a copy of RunsListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,}) {
  return _then(_RunsListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<RunSummary>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RunEventsResponse {

 List<RunEvent> get items; int get lastSequence;
/// Create a copy of RunEventsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunEventsResponseCopyWith<RunEventsResponse> get copyWith => _$RunEventsResponseCopyWithImpl<RunEventsResponse>(this as RunEventsResponse, _$identity);

  /// Serializes this RunEventsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunEventsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunEventsResponse&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.lastSequence, _this.lastSequence) || other.lastSequence == _this.lastSequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunEventsResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.lastSequence);
}

@override
String toString() {
  final _this = this as RunEventsResponse;
  return 'RunEventsResponse(items: ${_this.items}, lastSequence: ${_this.lastSequence})';
}


}

/// @nodoc
abstract mixin class $RunEventsResponseCopyWith<$Res>  {
  factory $RunEventsResponseCopyWith(RunEventsResponse value, $Res Function(RunEventsResponse) _then) = _$RunEventsResponseCopyWithImpl;
@useResult
$Res call({
 List<RunEvent> items, int lastSequence
});




}
/// @nodoc
class _$RunEventsResponseCopyWithImpl<$Res>
    implements $RunEventsResponseCopyWith<$Res> {
  _$RunEventsResponseCopyWithImpl(this._self, this._then);

  final RunEventsResponse _self;
  final $Res Function(RunEventsResponse) _then;

/// Create a copy of RunEventsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? lastSequence = null,}) {
  return _then(RunEventsResponse(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<RunEvent>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RunEventsResponse].
extension RunEventsResponsePatterns on RunEventsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunEventsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunEventsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunEventsResponse value)  $default,){
final _that = this;
switch (_that) {
case _RunEventsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunEventsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RunEventsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RunEvent> items,  int lastSequence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunEventsResponse() when $default != null:
return $default(_that.items,_that.lastSequence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RunEvent> items,  int lastSequence)  $default,) {final _that = this;
switch (_that) {
case _RunEventsResponse():
return $default(_that.items,_that.lastSequence);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RunEvent> items,  int lastSequence)?  $default,) {final _that = this;
switch (_that) {
case _RunEventsResponse() when $default != null:
return $default(_that.items,_that.lastSequence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunEventsResponse implements RunEventsResponse {
  const _RunEventsResponse({required  List<RunEvent> items, required this.lastSequence}): _items = items;
  factory _RunEventsResponse.fromJson(Map<String, dynamic> json) => _$RunEventsResponseFromJson(json);

 final  List<RunEvent> _items;
@override List<RunEvent> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int lastSequence;

/// Create a copy of RunEventsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunEventsResponseCopyWith<_RunEventsResponse> get copyWith => __$RunEventsResponseCopyWithImpl<_RunEventsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunEventsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunEventsResponse&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),lastSequence);
}

@override
String toString() {
    return 'RunEventsResponse(items: $items, lastSequence: $lastSequence)';
}


}

/// @nodoc
abstract mixin class _$RunEventsResponseCopyWith<$Res> implements $RunEventsResponseCopyWith<$Res> {
  factory _$RunEventsResponseCopyWith(_RunEventsResponse value, $Res Function(_RunEventsResponse) _then) = __$RunEventsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<RunEvent> items, int lastSequence
});




}
/// @nodoc
class __$RunEventsResponseCopyWithImpl<$Res>
    implements _$RunEventsResponseCopyWith<$Res> {
  __$RunEventsResponseCopyWithImpl(this._self, this._then);

  final _RunEventsResponse _self;
  final $Res Function(_RunEventsResponse) _then;

/// Create a copy of RunEventsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? lastSequence = null,}) {
  return _then(_RunEventsResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<RunEvent>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RunCheckpointsResponse {

 List<Checkpoint> get items;
/// Create a copy of RunCheckpointsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunCheckpointsResponseCopyWith<RunCheckpointsResponse> get copyWith => _$RunCheckpointsResponseCopyWithImpl<RunCheckpointsResponse>(this as RunCheckpointsResponse, _$identity);

  /// Serializes this RunCheckpointsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RunCheckpointsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunCheckpointsResponse&&const DeepCollectionEquality().equals(other.items, _this.items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RunCheckpointsResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as RunCheckpointsResponse;
  return 'RunCheckpointsResponse(items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $RunCheckpointsResponseCopyWith<$Res>  {
  factory $RunCheckpointsResponseCopyWith(RunCheckpointsResponse value, $Res Function(RunCheckpointsResponse) _then) = _$RunCheckpointsResponseCopyWithImpl;
@useResult
$Res call({
 List<Checkpoint> items
});




}
/// @nodoc
class _$RunCheckpointsResponseCopyWithImpl<$Res>
    implements $RunCheckpointsResponseCopyWith<$Res> {
  _$RunCheckpointsResponseCopyWithImpl(this._self, this._then);

  final RunCheckpointsResponse _self;
  final $Res Function(RunCheckpointsResponse) _then;

/// Create a copy of RunCheckpointsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(RunCheckpointsResponse(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Checkpoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [RunCheckpointsResponse].
extension RunCheckpointsResponsePatterns on RunCheckpointsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunCheckpointsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunCheckpointsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunCheckpointsResponse value)  $default,){
final _that = this;
switch (_that) {
case _RunCheckpointsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunCheckpointsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RunCheckpointsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Checkpoint> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunCheckpointsResponse() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Checkpoint> items)  $default,) {final _that = this;
switch (_that) {
case _RunCheckpointsResponse():
return $default(_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Checkpoint> items)?  $default,) {final _that = this;
switch (_that) {
case _RunCheckpointsResponse() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RunCheckpointsResponse implements RunCheckpointsResponse {
  const _RunCheckpointsResponse({required  List<Checkpoint> items}): _items = items;
  factory _RunCheckpointsResponse.fromJson(Map<String, dynamic> json) => _$RunCheckpointsResponseFromJson(json);

 final  List<Checkpoint> _items;
@override List<Checkpoint> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of RunCheckpointsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunCheckpointsResponseCopyWith<_RunCheckpointsResponse> get copyWith => __$RunCheckpointsResponseCopyWithImpl<_RunCheckpointsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunCheckpointsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunCheckpointsResponse&&const DeepCollectionEquality().equals(other.items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'RunCheckpointsResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$RunCheckpointsResponseCopyWith<$Res> implements $RunCheckpointsResponseCopyWith<$Res> {
  factory _$RunCheckpointsResponseCopyWith(_RunCheckpointsResponse value, $Res Function(_RunCheckpointsResponse) _then) = __$RunCheckpointsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<Checkpoint> items
});




}
/// @nodoc
class __$RunCheckpointsResponseCopyWithImpl<$Res>
    implements _$RunCheckpointsResponseCopyWith<$Res> {
  __$RunCheckpointsResponseCopyWithImpl(this._self, this._then);

  final _RunCheckpointsResponse _self;
  final $Res Function(_RunCheckpointsResponse) _then;

/// Create a copy of RunCheckpointsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_RunCheckpointsResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Checkpoint>,
  ));
}


}

// dart format on
