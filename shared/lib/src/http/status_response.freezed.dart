// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'status_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StatusResponse {

 BackendStatus get status; String get version; int get uptimeSeconds; String get dataDir; DatabaseStatus get database;
/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatusResponseCopyWith<StatusResponse> get copyWith => _$StatusResponseCopyWithImpl<StatusResponse>(this as StatusResponse, _$identity);

  /// Serializes this StatusResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StatusResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StatusResponse&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.uptimeSeconds, _this.uptimeSeconds) || other.uptimeSeconds == _this.uptimeSeconds)&&(identical(other.dataDir, _this.dataDir) || other.dataDir == _this.dataDir)&&(identical(other.database, _this.database) || other.database == _this.database));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StatusResponse;
  return Object.hash(runtimeType,_this.status,_this.version,_this.uptimeSeconds,_this.dataDir,_this.database);
}

@override
String toString() {
  final _this = this as StatusResponse;
  return 'StatusResponse(status: ${_this.status}, version: ${_this.version}, uptimeSeconds: ${_this.uptimeSeconds}, dataDir: ${_this.dataDir}, database: ${_this.database})';
}


}

/// @nodoc
abstract mixin class $StatusResponseCopyWith<$Res>  {
  factory $StatusResponseCopyWith(StatusResponse value, $Res Function(StatusResponse) _then) = _$StatusResponseCopyWithImpl;
@useResult
$Res call({
 BackendStatus status, String version, int uptimeSeconds, String dataDir, DatabaseStatus database
});


$DatabaseStatusCopyWith<$Res> get database;

}
/// @nodoc
class _$StatusResponseCopyWithImpl<$Res>
    implements $StatusResponseCopyWith<$Res> {
  _$StatusResponseCopyWithImpl(this._self, this._then);

  final StatusResponse _self;
  final $Res Function(StatusResponse) _then;

/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? version = null,Object? uptimeSeconds = null,Object? dataDir = null,Object? database = null,}) {
  return _then(StatusResponse(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BackendStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,uptimeSeconds: null == uptimeSeconds ? _self.uptimeSeconds : uptimeSeconds // ignore: cast_nullable_to_non_nullable
as int,dataDir: null == dataDir ? _self.dataDir : dataDir // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as DatabaseStatus,
  ));
}
/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DatabaseStatusCopyWith<$Res> get database {
  
  return $DatabaseStatusCopyWith<$Res>(_self.database, (value) {
    return _then(_self.copyWith(database: value));
  });
}
}


/// Adds pattern-matching-related methods to [StatusResponse].
extension StatusResponsePatterns on StatusResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StatusResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StatusResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StatusResponse value)  $default,){
final _that = this;
switch (_that) {
case _StatusResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StatusResponse value)?  $default,){
final _that = this;
switch (_that) {
case _StatusResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BackendStatus status,  String version,  int uptimeSeconds,  String dataDir,  DatabaseStatus database)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StatusResponse() when $default != null:
return $default(_that.status,_that.version,_that.uptimeSeconds,_that.dataDir,_that.database);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BackendStatus status,  String version,  int uptimeSeconds,  String dataDir,  DatabaseStatus database)  $default,) {final _that = this;
switch (_that) {
case _StatusResponse():
return $default(_that.status,_that.version,_that.uptimeSeconds,_that.dataDir,_that.database);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BackendStatus status,  String version,  int uptimeSeconds,  String dataDir,  DatabaseStatus database)?  $default,) {final _that = this;
switch (_that) {
case _StatusResponse() when $default != null:
return $default(_that.status,_that.version,_that.uptimeSeconds,_that.dataDir,_that.database);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StatusResponse implements StatusResponse {
  const _StatusResponse({required this.status, required this.version, required this.uptimeSeconds, required this.dataDir, required this.database});
  factory _StatusResponse.fromJson(Map<String, dynamic> json) => _$StatusResponseFromJson(json);

@override final  BackendStatus status;
@override final  String version;
@override final  int uptimeSeconds;
@override final  String dataDir;
@override final  DatabaseStatus database;

/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StatusResponseCopyWith<_StatusResponse> get copyWith => __$StatusResponseCopyWithImpl<_StatusResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StatusResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StatusResponse&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.uptimeSeconds, uptimeSeconds) || other.uptimeSeconds == uptimeSeconds)&&(identical(other.dataDir, dataDir) || other.dataDir == dataDir)&&(identical(other.database, database) || other.database == database));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,version,uptimeSeconds,dataDir,database);
}

@override
String toString() {
    return 'StatusResponse(status: $status, version: $version, uptimeSeconds: $uptimeSeconds, dataDir: $dataDir, database: $database)';
}


}

/// @nodoc
abstract mixin class _$StatusResponseCopyWith<$Res> implements $StatusResponseCopyWith<$Res> {
  factory _$StatusResponseCopyWith(_StatusResponse value, $Res Function(_StatusResponse) _then) = __$StatusResponseCopyWithImpl;
@override @useResult
$Res call({
 BackendStatus status, String version, int uptimeSeconds, String dataDir, DatabaseStatus database
});


@override $DatabaseStatusCopyWith<$Res> get database;

}
/// @nodoc
class __$StatusResponseCopyWithImpl<$Res>
    implements _$StatusResponseCopyWith<$Res> {
  __$StatusResponseCopyWithImpl(this._self, this._then);

  final _StatusResponse _self;
  final $Res Function(_StatusResponse) _then;

/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? version = null,Object? uptimeSeconds = null,Object? dataDir = null,Object? database = null,}) {
  return _then(_StatusResponse(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BackendStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,uptimeSeconds: null == uptimeSeconds ? _self.uptimeSeconds : uptimeSeconds // ignore: cast_nullable_to_non_nullable
as int,dataDir: null == dataDir ? _self.dataDir : dataDir // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as DatabaseStatus,
  ));
}

/// Create a copy of StatusResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DatabaseStatusCopyWith<$Res> get database {
  
  return $DatabaseStatusCopyWith<$Res>(_self.database, (value) {
    return _then(_self.copyWith(database: value));
  });
}
}


/// @nodoc
mixin _$DatabaseStatus {

@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson) bool get ok; int? get schemaVersion; String? get error;
/// Create a copy of DatabaseStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DatabaseStatusCopyWith<DatabaseStatus> get copyWith => _$DatabaseStatusCopyWithImpl<DatabaseStatus>(this as DatabaseStatus, _$identity);

  /// Serializes this DatabaseStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DatabaseStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DatabaseStatus&&(identical(other.ok, _this.ok) || other.ok == _this.ok)&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DatabaseStatus;
  return Object.hash(runtimeType,_this.ok,_this.schemaVersion,_this.error);
}

@override
String toString() {
  final _this = this as DatabaseStatus;
  return 'DatabaseStatus(ok: ${_this.ok}, schemaVersion: ${_this.schemaVersion}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $DatabaseStatusCopyWith<$Res>  {
  factory $DatabaseStatusCopyWith(DatabaseStatus value, $Res Function(DatabaseStatus) _then) = _$DatabaseStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson) bool ok, int? schemaVersion, String? error
});




}
/// @nodoc
class _$DatabaseStatusCopyWithImpl<$Res>
    implements $DatabaseStatusCopyWith<$Res> {
  _$DatabaseStatusCopyWithImpl(this._self, this._then);

  final DatabaseStatus _self;
  final $Res Function(DatabaseStatus) _then;

/// Create a copy of DatabaseStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ok = null,Object? schemaVersion = freezed,Object? error = freezed,}) {
  return _then(DatabaseStatus(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,schemaVersion: freezed == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DatabaseStatus].
extension DatabaseStatusPatterns on DatabaseStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DatabaseStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DatabaseStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DatabaseStatus value)  $default,){
final _that = this;
switch (_that) {
case _DatabaseStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DatabaseStatus value)?  $default,){
final _that = this;
switch (_that) {
case _DatabaseStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson)  bool ok,  int? schemaVersion,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DatabaseStatus() when $default != null:
return $default(_that.ok,_that.schemaVersion,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson)  bool ok,  int? schemaVersion,  String? error)  $default,) {final _that = this;
switch (_that) {
case _DatabaseStatus():
return $default(_that.ok,_that.schemaVersion,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson)  bool ok,  int? schemaVersion,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _DatabaseStatus() when $default != null:
return $default(_that.ok,_that.schemaVersion,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DatabaseStatus implements DatabaseStatus {
  const _DatabaseStatus({@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson) required this.ok, this.schemaVersion, this.error});
  factory _DatabaseStatus.fromJson(Map<String, dynamic> json) => _$DatabaseStatusFromJson(json);

@override@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson) final  bool ok;
@override final  int? schemaVersion;
@override final  String? error;

/// Create a copy of DatabaseStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DatabaseStatusCopyWith<_DatabaseStatus> get copyWith => __$DatabaseStatusCopyWithImpl<_DatabaseStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DatabaseStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DatabaseStatus&&(identical(other.ok, ok) || other.ok == ok)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ok,schemaVersion,error);
}

@override
String toString() {
    return 'DatabaseStatus(ok: $ok, schemaVersion: $schemaVersion, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DatabaseStatusCopyWith<$Res> implements $DatabaseStatusCopyWith<$Res> {
  factory _$DatabaseStatusCopyWith(_DatabaseStatus value, $Res Function(_DatabaseStatus) _then) = __$DatabaseStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'status', fromJson: _dbStatusFromJson, toJson: _dbStatusToJson) bool ok, int? schemaVersion, String? error
});




}
/// @nodoc
class __$DatabaseStatusCopyWithImpl<$Res>
    implements _$DatabaseStatusCopyWith<$Res> {
  __$DatabaseStatusCopyWithImpl(this._self, this._then);

  final _DatabaseStatus _self;
  final $Res Function(_DatabaseStatus) _then;

/// Create a copy of DatabaseStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ok = null,Object? schemaVersion = freezed,Object? error = freezed,}) {
  return _then(_DatabaseStatus(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,schemaVersion: freezed == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
