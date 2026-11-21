// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harnesses_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HarnessesState {

 List<HarnessInfo> get harnesses; bool get isRefreshingAll; Set<HarnessId> get refreshingIds;
/// Create a copy of HarnessesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HarnessesStateCopyWith<HarnessesState> get copyWith => _$HarnessesStateCopyWithImpl<HarnessesState>(this as HarnessesState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HarnessesState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HarnessesState&&const DeepCollectionEquality().equals(other.harnesses, _this.harnesses)&&(identical(other.isRefreshingAll, _this.isRefreshingAll) || other.isRefreshingAll == _this.isRefreshingAll)&&const DeepCollectionEquality().equals(other.refreshingIds, _this.refreshingIds));
}


@override
int get hashCode {
  final _this = this as HarnessesState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.harnesses),_this.isRefreshingAll,const DeepCollectionEquality().hash(_this.refreshingIds));
}

@override
String toString() {
  final _this = this as HarnessesState;
  return 'HarnessesState(harnesses: ${_this.harnesses}, isRefreshingAll: ${_this.isRefreshingAll}, refreshingIds: ${_this.refreshingIds})';
}


}

/// @nodoc
abstract mixin class $HarnessesStateCopyWith<$Res>  {
  factory $HarnessesStateCopyWith(HarnessesState value, $Res Function(HarnessesState) _then) = _$HarnessesStateCopyWithImpl;
@useResult
$Res call({
 List<HarnessInfo> harnesses, bool isRefreshingAll, Set<HarnessId> refreshingIds
});




}
/// @nodoc
class _$HarnessesStateCopyWithImpl<$Res>
    implements $HarnessesStateCopyWith<$Res> {
  _$HarnessesStateCopyWithImpl(this._self, this._then);

  final HarnessesState _self;
  final $Res Function(HarnessesState) _then;

/// Create a copy of HarnessesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? harnesses = null,Object? isRefreshingAll = null,Object? refreshingIds = null,}) {
  return _then(HarnessesState(
harnesses: null == harnesses ? _self.harnesses : harnesses // ignore: cast_nullable_to_non_nullable
as List<HarnessInfo>,isRefreshingAll: null == isRefreshingAll ? _self.isRefreshingAll : isRefreshingAll // ignore: cast_nullable_to_non_nullable
as bool,refreshingIds: null == refreshingIds ? _self.refreshingIds : refreshingIds // ignore: cast_nullable_to_non_nullable
as Set<HarnessId>,
  ));
}

}


/// Adds pattern-matching-related methods to [HarnessesState].
extension HarnessesStatePatterns on HarnessesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HarnessesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HarnessesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HarnessesState value)  $default,){
final _that = this;
switch (_that) {
case _HarnessesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HarnessesState value)?  $default,){
final _that = this;
switch (_that) {
case _HarnessesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<HarnessInfo> harnesses,  bool isRefreshingAll,  Set<HarnessId> refreshingIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HarnessesState() when $default != null:
return $default(_that.harnesses,_that.isRefreshingAll,_that.refreshingIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<HarnessInfo> harnesses,  bool isRefreshingAll,  Set<HarnessId> refreshingIds)  $default,) {final _that = this;
switch (_that) {
case _HarnessesState():
return $default(_that.harnesses,_that.isRefreshingAll,_that.refreshingIds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<HarnessInfo> harnesses,  bool isRefreshingAll,  Set<HarnessId> refreshingIds)?  $default,) {final _that = this;
switch (_that) {
case _HarnessesState() when $default != null:
return $default(_that.harnesses,_that.isRefreshingAll,_that.refreshingIds);case _:
  return null;

}
}

}

/// @nodoc


class _HarnessesState implements HarnessesState {
  const _HarnessesState({required  List<HarnessInfo> harnesses, this.isRefreshingAll = false,  Set<HarnessId> refreshingIds = const <HarnessId>{}}): _harnesses = harnesses,_refreshingIds = refreshingIds;
  

 final  List<HarnessInfo> _harnesses;
@override List<HarnessInfo> get harnesses {
  if (_harnesses is EqualUnmodifiableListView) return _harnesses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_harnesses);
}

@override@JsonKey() final  bool isRefreshingAll;
 final  Set<HarnessId> _refreshingIds;
@override@JsonKey() Set<HarnessId> get refreshingIds {
  if (_refreshingIds is EqualUnmodifiableSetView) return _refreshingIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_refreshingIds);
}


/// Create a copy of HarnessesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HarnessesStateCopyWith<_HarnessesState> get copyWith => __$HarnessesStateCopyWithImpl<_HarnessesState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HarnessesState&&const DeepCollectionEquality().equals(other.harnesses, _harnesses)&&(identical(other.isRefreshingAll, isRefreshingAll) || other.isRefreshingAll == isRefreshingAll)&&const DeepCollectionEquality().equals(other.refreshingIds, _refreshingIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_harnesses),isRefreshingAll,const DeepCollectionEquality().hash(_refreshingIds));
}

@override
String toString() {
    return 'HarnessesState(harnesses: $harnesses, isRefreshingAll: $isRefreshingAll, refreshingIds: $refreshingIds)';
}


}

/// @nodoc
abstract mixin class _$HarnessesStateCopyWith<$Res> implements $HarnessesStateCopyWith<$Res> {
  factory _$HarnessesStateCopyWith(_HarnessesState value, $Res Function(_HarnessesState) _then) = __$HarnessesStateCopyWithImpl;
@override @useResult
$Res call({
 List<HarnessInfo> harnesses, bool isRefreshingAll, Set<HarnessId> refreshingIds
});




}
/// @nodoc
class __$HarnessesStateCopyWithImpl<$Res>
    implements _$HarnessesStateCopyWith<$Res> {
  __$HarnessesStateCopyWithImpl(this._self, this._then);

  final _HarnessesState _self;
  final $Res Function(_HarnessesState) _then;

/// Create a copy of HarnessesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? harnesses = null,Object? isRefreshingAll = null,Object? refreshingIds = null,}) {
  return _then(_HarnessesState(
harnesses: null == harnesses ? _self._harnesses : harnesses // ignore: cast_nullable_to_non_nullable
as List<HarnessInfo>,isRefreshingAll: null == isRefreshingAll ? _self.isRefreshingAll : isRefreshingAll // ignore: cast_nullable_to_non_nullable
as bool,refreshingIds: null == refreshingIds ? _self._refreshingIds : refreshingIds // ignore: cast_nullable_to_non_nullable
as Set<HarnessId>,
  ));
}


}

// dart format on
