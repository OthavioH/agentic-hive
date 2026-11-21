// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessInfo {

 HarnessId get id; String get displayName; HarnessStatus get status; DateTime get checkedAt; String? get version; String? get executablePath; String? get errorMessage;
/// Create a copy of HarnessInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HarnessInfoCopyWith<HarnessInfo> get copyWith => _$HarnessInfoCopyWithImpl<HarnessInfo>(this as HarnessInfo, _$identity);

  /// Serializes this HarnessInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HarnessInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HarnessInfo&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.checkedAt, _this.checkedAt) || other.checkedAt == _this.checkedAt)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.executablePath, _this.executablePath) || other.executablePath == _this.executablePath)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HarnessInfo;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.status,_this.checkedAt,_this.version,_this.executablePath,_this.errorMessage);
}

@override
String toString() {
  final _this = this as HarnessInfo;
  return 'HarnessInfo(id: ${_this.id}, displayName: ${_this.displayName}, status: ${_this.status}, checkedAt: ${_this.checkedAt}, version: ${_this.version}, executablePath: ${_this.executablePath}, errorMessage: ${_this.errorMessage})';
}


}

/// @nodoc
abstract mixin class $HarnessInfoCopyWith<$Res>  {
  factory $HarnessInfoCopyWith(HarnessInfo value, $Res Function(HarnessInfo) _then) = _$HarnessInfoCopyWithImpl;
@useResult
$Res call({
 HarnessId id, String displayName, HarnessStatus status, DateTime checkedAt, String? version, String? executablePath, String? errorMessage
});




}
/// @nodoc
class _$HarnessInfoCopyWithImpl<$Res>
    implements $HarnessInfoCopyWith<$Res> {
  _$HarnessInfoCopyWithImpl(this._self, this._then);

  final HarnessInfo _self;
  final $Res Function(HarnessInfo) _then;

/// Create a copy of HarnessInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? status = null,Object? checkedAt = null,Object? version = freezed,Object? executablePath = freezed,Object? errorMessage = freezed,}) {
  return _then(HarnessInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as HarnessId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HarnessStatus,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,executablePath: freezed == executablePath ? _self.executablePath : executablePath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HarnessInfo].
extension HarnessInfoPatterns on HarnessInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HarnessInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HarnessInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HarnessInfo value)  $default,){
final _that = this;
switch (_that) {
case _HarnessInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HarnessInfo value)?  $default,){
final _that = this;
switch (_that) {
case _HarnessInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HarnessId id,  String displayName,  HarnessStatus status,  DateTime checkedAt,  String? version,  String? executablePath,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HarnessInfo() when $default != null:
return $default(_that.id,_that.displayName,_that.status,_that.checkedAt,_that.version,_that.executablePath,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HarnessId id,  String displayName,  HarnessStatus status,  DateTime checkedAt,  String? version,  String? executablePath,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _HarnessInfo():
return $default(_that.id,_that.displayName,_that.status,_that.checkedAt,_that.version,_that.executablePath,_that.errorMessage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HarnessId id,  String displayName,  HarnessStatus status,  DateTime checkedAt,  String? version,  String? executablePath,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _HarnessInfo() when $default != null:
return $default(_that.id,_that.displayName,_that.status,_that.checkedAt,_that.version,_that.executablePath,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HarnessInfo implements HarnessInfo {
  const _HarnessInfo({required this.id, required this.displayName, required this.status, required this.checkedAt, this.version, this.executablePath, this.errorMessage});
  factory _HarnessInfo.fromJson(Map<String, dynamic> json) => _$HarnessInfoFromJson(json);

@override final  HarnessId id;
@override final  String displayName;
@override final  HarnessStatus status;
@override final  DateTime checkedAt;
@override final  String? version;
@override final  String? executablePath;
@override final  String? errorMessage;

/// Create a copy of HarnessInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HarnessInfoCopyWith<_HarnessInfo> get copyWith => __$HarnessInfoCopyWithImpl<_HarnessInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HarnessInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HarnessInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.status, status) || other.status == status)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.executablePath, executablePath) || other.executablePath == executablePath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,status,checkedAt,version,executablePath,errorMessage);
}

@override
String toString() {
    return 'HarnessInfo(id: $id, displayName: $displayName, status: $status, checkedAt: $checkedAt, version: $version, executablePath: $executablePath, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$HarnessInfoCopyWith<$Res> implements $HarnessInfoCopyWith<$Res> {
  factory _$HarnessInfoCopyWith(_HarnessInfo value, $Res Function(_HarnessInfo) _then) = __$HarnessInfoCopyWithImpl;
@override @useResult
$Res call({
 HarnessId id, String displayName, HarnessStatus status, DateTime checkedAt, String? version, String? executablePath, String? errorMessage
});




}
/// @nodoc
class __$HarnessInfoCopyWithImpl<$Res>
    implements _$HarnessInfoCopyWith<$Res> {
  __$HarnessInfoCopyWithImpl(this._self, this._then);

  final _HarnessInfo _self;
  final $Res Function(_HarnessInfo) _then;

/// Create a copy of HarnessInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? status = null,Object? checkedAt = null,Object? version = freezed,Object? executablePath = freezed,Object? errorMessage = freezed,}) {
  return _then(_HarnessInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as HarnessId,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HarnessStatus,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,executablePath: freezed == executablePath ? _self.executablePath : executablePath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
