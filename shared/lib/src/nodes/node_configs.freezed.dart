// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'node_configs.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessNodeConfig {

 String? get agentId; String? get additionalInstructions; String? get workingDirectory; int? get timeoutSeconds; List<String> get extraArgs;
/// Create a copy of HarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HarnessNodeConfigCopyWith<HarnessNodeConfig> get copyWith => _$HarnessNodeConfigCopyWithImpl<HarnessNodeConfig>(this as HarnessNodeConfig, _$identity);

  /// Serializes this HarnessNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HarnessNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HarnessNodeConfig&&(identical(other.agentId, _this.agentId) || other.agentId == _this.agentId)&&(identical(other.additionalInstructions, _this.additionalInstructions) || other.additionalInstructions == _this.additionalInstructions)&&(identical(other.workingDirectory, _this.workingDirectory) || other.workingDirectory == _this.workingDirectory)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds)&&const DeepCollectionEquality().equals(other.extraArgs, _this.extraArgs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HarnessNodeConfig;
  return Object.hash(runtimeType,_this.agentId,_this.additionalInstructions,_this.workingDirectory,_this.timeoutSeconds,const DeepCollectionEquality().hash(_this.extraArgs));
}

@override
String toString() {
  final _this = this as HarnessNodeConfig;
  return 'HarnessNodeConfig(agentId: ${_this.agentId}, additionalInstructions: ${_this.additionalInstructions}, workingDirectory: ${_this.workingDirectory}, timeoutSeconds: ${_this.timeoutSeconds}, extraArgs: ${_this.extraArgs})';
}


}

/// @nodoc
abstract mixin class $HarnessNodeConfigCopyWith<$Res>  {
  factory $HarnessNodeConfigCopyWith(HarnessNodeConfig value, $Res Function(HarnessNodeConfig) _then) = _$HarnessNodeConfigCopyWithImpl;
@useResult
$Res call({
 String? agentId, String? additionalInstructions, String? workingDirectory, int? timeoutSeconds, List<String> extraArgs
});




}
/// @nodoc
class _$HarnessNodeConfigCopyWithImpl<$Res>
    implements $HarnessNodeConfigCopyWith<$Res> {
  _$HarnessNodeConfigCopyWithImpl(this._self, this._then);

  final HarnessNodeConfig _self;
  final $Res Function(HarnessNodeConfig) _then;

/// Create a copy of HarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = freezed,Object? additionalInstructions = freezed,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? extraArgs = null,}) {
  return _then(HarnessNodeConfig(
agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,additionalInstructions: freezed == additionalInstructions ? _self.additionalInstructions : additionalInstructions // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,extraArgs: null == extraArgs ? _self.extraArgs : extraArgs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [HarnessNodeConfig].
extension HarnessNodeConfigPatterns on HarnessNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HarnessNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HarnessNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HarnessNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _HarnessNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HarnessNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _HarnessNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HarnessNodeConfig() when $default != null:
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs)  $default,) {final _that = this;
switch (_that) {
case _HarnessNodeConfig():
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs)?  $default,) {final _that = this;
switch (_that) {
case _HarnessNodeConfig() when $default != null:
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HarnessNodeConfig extends HarnessNodeConfig {
  const _HarnessNodeConfig({this.agentId, this.additionalInstructions, this.workingDirectory, this.timeoutSeconds,  List<String> extraArgs = const <String>[]}): _extraArgs = extraArgs,super._();
  factory _HarnessNodeConfig.fromJson(Map<String, dynamic> json) => _$HarnessNodeConfigFromJson(json);

@override final  String? agentId;
@override final  String? additionalInstructions;
@override final  String? workingDirectory;
@override final  int? timeoutSeconds;
 final  List<String> _extraArgs;
@override@JsonKey() List<String> get extraArgs {
  if (_extraArgs is EqualUnmodifiableListView) return _extraArgs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraArgs);
}


/// Create a copy of HarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HarnessNodeConfigCopyWith<_HarnessNodeConfig> get copyWith => __$HarnessNodeConfigCopyWithImpl<_HarnessNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HarnessNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HarnessNodeConfig&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.additionalInstructions, additionalInstructions) || other.additionalInstructions == additionalInstructions)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&const DeepCollectionEquality().equals(other.extraArgs, _extraArgs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,agentId,additionalInstructions,workingDirectory,timeoutSeconds,const DeepCollectionEquality().hash(_extraArgs));
}

@override
String toString() {
    return 'HarnessNodeConfig(agentId: $agentId, additionalInstructions: $additionalInstructions, workingDirectory: $workingDirectory, timeoutSeconds: $timeoutSeconds, extraArgs: $extraArgs)';
}


}

/// @nodoc
abstract mixin class _$HarnessNodeConfigCopyWith<$Res> implements $HarnessNodeConfigCopyWith<$Res> {
  factory _$HarnessNodeConfigCopyWith(_HarnessNodeConfig value, $Res Function(_HarnessNodeConfig) _then) = __$HarnessNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String? agentId, String? additionalInstructions, String? workingDirectory, int? timeoutSeconds, List<String> extraArgs
});




}
/// @nodoc
class __$HarnessNodeConfigCopyWithImpl<$Res>
    implements _$HarnessNodeConfigCopyWith<$Res> {
  __$HarnessNodeConfigCopyWithImpl(this._self, this._then);

  final _HarnessNodeConfig _self;
  final $Res Function(_HarnessNodeConfig) _then;

/// Create a copy of HarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = freezed,Object? additionalInstructions = freezed,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? extraArgs = null,}) {
  return _then(_HarnessNodeConfig(
agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,additionalInstructions: freezed == additionalInstructions ? _self.additionalInstructions : additionalInstructions // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,extraArgs: null == extraArgs ? _self._extraArgs : extraArgs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$TerminalHarnessNodeConfig {

 String? get agentId; String? get additionalInstructions; String? get workingDirectory; int? get timeoutSeconds; List<String> get extraArgs; String? get command; List<String> get args;
/// Create a copy of TerminalHarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalHarnessNodeConfigCopyWith<TerminalHarnessNodeConfig> get copyWith => _$TerminalHarnessNodeConfigCopyWithImpl<TerminalHarnessNodeConfig>(this as TerminalHarnessNodeConfig, _$identity);

  /// Serializes this TerminalHarnessNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TerminalHarnessNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalHarnessNodeConfig&&(identical(other.agentId, _this.agentId) || other.agentId == _this.agentId)&&(identical(other.additionalInstructions, _this.additionalInstructions) || other.additionalInstructions == _this.additionalInstructions)&&(identical(other.workingDirectory, _this.workingDirectory) || other.workingDirectory == _this.workingDirectory)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds)&&const DeepCollectionEquality().equals(other.extraArgs, _this.extraArgs)&&(identical(other.command, _this.command) || other.command == _this.command)&&const DeepCollectionEquality().equals(other.args, _this.args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TerminalHarnessNodeConfig;
  return Object.hash(runtimeType,_this.agentId,_this.additionalInstructions,_this.workingDirectory,_this.timeoutSeconds,const DeepCollectionEquality().hash(_this.extraArgs),_this.command,const DeepCollectionEquality().hash(_this.args));
}

@override
String toString() {
  final _this = this as TerminalHarnessNodeConfig;
  return 'TerminalHarnessNodeConfig(agentId: ${_this.agentId}, additionalInstructions: ${_this.additionalInstructions}, workingDirectory: ${_this.workingDirectory}, timeoutSeconds: ${_this.timeoutSeconds}, extraArgs: ${_this.extraArgs}, command: ${_this.command}, args: ${_this.args})';
}


}

/// @nodoc
abstract mixin class $TerminalHarnessNodeConfigCopyWith<$Res>  {
  factory $TerminalHarnessNodeConfigCopyWith(TerminalHarnessNodeConfig value, $Res Function(TerminalHarnessNodeConfig) _then) = _$TerminalHarnessNodeConfigCopyWithImpl;
@useResult
$Res call({
 String? agentId, String? additionalInstructions, String? workingDirectory, int? timeoutSeconds, List<String> extraArgs, String? command, List<String> args
});




}
/// @nodoc
class _$TerminalHarnessNodeConfigCopyWithImpl<$Res>
    implements $TerminalHarnessNodeConfigCopyWith<$Res> {
  _$TerminalHarnessNodeConfigCopyWithImpl(this._self, this._then);

  final TerminalHarnessNodeConfig _self;
  final $Res Function(TerminalHarnessNodeConfig) _then;

/// Create a copy of TerminalHarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = freezed,Object? additionalInstructions = freezed,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? extraArgs = null,Object? command = freezed,Object? args = null,}) {
  return _then(TerminalHarnessNodeConfig(
agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,additionalInstructions: freezed == additionalInstructions ? _self.additionalInstructions : additionalInstructions // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,extraArgs: null == extraArgs ? _self.extraArgs : extraArgs // ignore: cast_nullable_to_non_nullable
as List<String>,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalHarnessNodeConfig].
extension TerminalHarnessNodeConfigPatterns on TerminalHarnessNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalHarnessNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalHarnessNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalHarnessNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs,  String? command,  List<String> args)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig() when $default != null:
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs,_that.command,_that.args);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs,  String? command,  List<String> args)  $default,) {final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig():
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs,_that.command,_that.args);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? agentId,  String? additionalInstructions,  String? workingDirectory,  int? timeoutSeconds,  List<String> extraArgs,  String? command,  List<String> args)?  $default,) {final _that = this;
switch (_that) {
case _TerminalHarnessNodeConfig() when $default != null:
return $default(_that.agentId,_that.additionalInstructions,_that.workingDirectory,_that.timeoutSeconds,_that.extraArgs,_that.command,_that.args);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalHarnessNodeConfig extends TerminalHarnessNodeConfig {
  const _TerminalHarnessNodeConfig({this.agentId, this.additionalInstructions, this.workingDirectory, this.timeoutSeconds,  List<String> extraArgs = const <String>[], this.command,  List<String> args = const <String>[]}): _extraArgs = extraArgs,_args = args,super._();
  factory _TerminalHarnessNodeConfig.fromJson(Map<String, dynamic> json) => _$TerminalHarnessNodeConfigFromJson(json);

@override final  String? agentId;
@override final  String? additionalInstructions;
@override final  String? workingDirectory;
@override final  int? timeoutSeconds;
 final  List<String> _extraArgs;
@override@JsonKey() List<String> get extraArgs {
  if (_extraArgs is EqualUnmodifiableListView) return _extraArgs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraArgs);
}

@override final  String? command;
 final  List<String> _args;
@override@JsonKey() List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}


/// Create a copy of TerminalHarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalHarnessNodeConfigCopyWith<_TerminalHarnessNodeConfig> get copyWith => __$TerminalHarnessNodeConfigCopyWithImpl<_TerminalHarnessNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalHarnessNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalHarnessNodeConfig&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.additionalInstructions, additionalInstructions) || other.additionalInstructions == additionalInstructions)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&const DeepCollectionEquality().equals(other.extraArgs, _extraArgs)&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.args, _args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,agentId,additionalInstructions,workingDirectory,timeoutSeconds,const DeepCollectionEquality().hash(_extraArgs),command,const DeepCollectionEquality().hash(_args));
}

@override
String toString() {
    return 'TerminalHarnessNodeConfig(agentId: $agentId, additionalInstructions: $additionalInstructions, workingDirectory: $workingDirectory, timeoutSeconds: $timeoutSeconds, extraArgs: $extraArgs, command: $command, args: $args)';
}


}

/// @nodoc
abstract mixin class _$TerminalHarnessNodeConfigCopyWith<$Res> implements $TerminalHarnessNodeConfigCopyWith<$Res> {
  factory _$TerminalHarnessNodeConfigCopyWith(_TerminalHarnessNodeConfig value, $Res Function(_TerminalHarnessNodeConfig) _then) = __$TerminalHarnessNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String? agentId, String? additionalInstructions, String? workingDirectory, int? timeoutSeconds, List<String> extraArgs, String? command, List<String> args
});




}
/// @nodoc
class __$TerminalHarnessNodeConfigCopyWithImpl<$Res>
    implements _$TerminalHarnessNodeConfigCopyWith<$Res> {
  __$TerminalHarnessNodeConfigCopyWithImpl(this._self, this._then);

  final _TerminalHarnessNodeConfig _self;
  final $Res Function(_TerminalHarnessNodeConfig) _then;

/// Create a copy of TerminalHarnessNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = freezed,Object? additionalInstructions = freezed,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? extraArgs = null,Object? command = freezed,Object? args = null,}) {
  return _then(_TerminalHarnessNodeConfig(
agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,additionalInstructions: freezed == additionalInstructions ? _self.additionalInstructions : additionalInstructions // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,extraArgs: null == extraArgs ? _self._extraArgs : extraArgs // ignore: cast_nullable_to_non_nullable
as List<String>,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$CommandNodeConfig {

 String get command; List<String> get args; String? get workingDirectory; int? get timeoutSeconds; Map<String, String> get env;
/// Create a copy of CommandNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandNodeConfigCopyWith<CommandNodeConfig> get copyWith => _$CommandNodeConfigCopyWithImpl<CommandNodeConfig>(this as CommandNodeConfig, _$identity);

  /// Serializes this CommandNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CommandNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandNodeConfig&&(identical(other.command, _this.command) || other.command == _this.command)&&const DeepCollectionEquality().equals(other.args, _this.args)&&(identical(other.workingDirectory, _this.workingDirectory) || other.workingDirectory == _this.workingDirectory)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds)&&const DeepCollectionEquality().equals(other.env, _this.env));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CommandNodeConfig;
  return Object.hash(runtimeType,_this.command,const DeepCollectionEquality().hash(_this.args),_this.workingDirectory,_this.timeoutSeconds,const DeepCollectionEquality().hash(_this.env));
}

@override
String toString() {
  final _this = this as CommandNodeConfig;
  return 'CommandNodeConfig(command: ${_this.command}, args: ${_this.args}, workingDirectory: ${_this.workingDirectory}, timeoutSeconds: ${_this.timeoutSeconds}, env: ${_this.env})';
}


}

/// @nodoc
abstract mixin class $CommandNodeConfigCopyWith<$Res>  {
  factory $CommandNodeConfigCopyWith(CommandNodeConfig value, $Res Function(CommandNodeConfig) _then) = _$CommandNodeConfigCopyWithImpl;
@useResult
$Res call({
 String command, List<String> args, String? workingDirectory, int? timeoutSeconds, Map<String, String> env
});




}
/// @nodoc
class _$CommandNodeConfigCopyWithImpl<$Res>
    implements $CommandNodeConfigCopyWith<$Res> {
  _$CommandNodeConfigCopyWithImpl(this._self, this._then);

  final CommandNodeConfig _self;
  final $Res Function(CommandNodeConfig) _then;

/// Create a copy of CommandNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = null,Object? args = null,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? env = null,}) {
  return _then(CommandNodeConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,env: null == env ? _self.env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommandNodeConfig].
extension CommandNodeConfigPatterns on CommandNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommandNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommandNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommandNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _CommandNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommandNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CommandNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds,  Map<String, String> env)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommandNodeConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds,_that.env);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds,  Map<String, String> env)  $default,) {final _that = this;
switch (_that) {
case _CommandNodeConfig():
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds,_that.env);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds,  Map<String, String> env)?  $default,) {final _that = this;
switch (_that) {
case _CommandNodeConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds,_that.env);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommandNodeConfig extends CommandNodeConfig {
  const _CommandNodeConfig({required this.command,  List<String> args = const <String>[], this.workingDirectory, this.timeoutSeconds,  Map<String, String> env = const <String, String>{}}): _args = args,_env = env,super._();
  factory _CommandNodeConfig.fromJson(Map<String, dynamic> json) => _$CommandNodeConfigFromJson(json);

@override final  String command;
 final  List<String> _args;
@override@JsonKey() List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}

@override final  String? workingDirectory;
@override final  int? timeoutSeconds;
 final  Map<String, String> _env;
@override@JsonKey() Map<String, String> get env {
  if (_env is EqualUnmodifiableMapView) return _env;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_env);
}


/// Create a copy of CommandNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandNodeConfigCopyWith<_CommandNodeConfig> get copyWith => __$CommandNodeConfigCopyWithImpl<_CommandNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandNodeConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.args, _args)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&const DeepCollectionEquality().equals(other.env, _env));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,const DeepCollectionEquality().hash(_args),workingDirectory,timeoutSeconds,const DeepCollectionEquality().hash(_env));
}

@override
String toString() {
    return 'CommandNodeConfig(command: $command, args: $args, workingDirectory: $workingDirectory, timeoutSeconds: $timeoutSeconds, env: $env)';
}


}

/// @nodoc
abstract mixin class _$CommandNodeConfigCopyWith<$Res> implements $CommandNodeConfigCopyWith<$Res> {
  factory _$CommandNodeConfigCopyWith(_CommandNodeConfig value, $Res Function(_CommandNodeConfig) _then) = __$CommandNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String command, List<String> args, String? workingDirectory, int? timeoutSeconds, Map<String, String> env
});




}
/// @nodoc
class __$CommandNodeConfigCopyWithImpl<$Res>
    implements _$CommandNodeConfigCopyWith<$Res> {
  __$CommandNodeConfigCopyWithImpl(this._self, this._then);

  final _CommandNodeConfig _self;
  final $Res Function(_CommandNodeConfig) _then;

/// Create a copy of CommandNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? args = null,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,Object? env = null,}) {
  return _then(_CommandNodeConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,env: null == env ? _self._env : env // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}


/// @nodoc
mixin _$TestsValidatorNodeConfig {

 String get command; List<String> get args; String? get workingDirectory; int? get timeoutSeconds;
/// Create a copy of TestsValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TestsValidatorNodeConfigCopyWith<TestsValidatorNodeConfig> get copyWith => _$TestsValidatorNodeConfigCopyWithImpl<TestsValidatorNodeConfig>(this as TestsValidatorNodeConfig, _$identity);

  /// Serializes this TestsValidatorNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TestsValidatorNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TestsValidatorNodeConfig&&(identical(other.command, _this.command) || other.command == _this.command)&&const DeepCollectionEquality().equals(other.args, _this.args)&&(identical(other.workingDirectory, _this.workingDirectory) || other.workingDirectory == _this.workingDirectory)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TestsValidatorNodeConfig;
  return Object.hash(runtimeType,_this.command,const DeepCollectionEquality().hash(_this.args),_this.workingDirectory,_this.timeoutSeconds);
}

@override
String toString() {
  final _this = this as TestsValidatorNodeConfig;
  return 'TestsValidatorNodeConfig(command: ${_this.command}, args: ${_this.args}, workingDirectory: ${_this.workingDirectory}, timeoutSeconds: ${_this.timeoutSeconds})';
}


}

/// @nodoc
abstract mixin class $TestsValidatorNodeConfigCopyWith<$Res>  {
  factory $TestsValidatorNodeConfigCopyWith(TestsValidatorNodeConfig value, $Res Function(TestsValidatorNodeConfig) _then) = _$TestsValidatorNodeConfigCopyWithImpl;
@useResult
$Res call({
 String command, List<String> args, String? workingDirectory, int? timeoutSeconds
});




}
/// @nodoc
class _$TestsValidatorNodeConfigCopyWithImpl<$Res>
    implements $TestsValidatorNodeConfigCopyWith<$Res> {
  _$TestsValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final TestsValidatorNodeConfig _self;
  final $Res Function(TestsValidatorNodeConfig) _then;

/// Create a copy of TestsValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = null,Object? args = null,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,}) {
  return _then(TestsValidatorNodeConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TestsValidatorNodeConfig].
extension TestsValidatorNodeConfigPatterns on TestsValidatorNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TestsValidatorNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TestsValidatorNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TestsValidatorNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig():
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String command,  List<String> args,  String? workingDirectory,  int? timeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _TestsValidatorNodeConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.timeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TestsValidatorNodeConfig extends TestsValidatorNodeConfig {
  const _TestsValidatorNodeConfig({required this.command,  List<String> args = const <String>[], this.workingDirectory, this.timeoutSeconds}): _args = args,super._();
  factory _TestsValidatorNodeConfig.fromJson(Map<String, dynamic> json) => _$TestsValidatorNodeConfigFromJson(json);

@override final  String command;
 final  List<String> _args;
@override@JsonKey() List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}

@override final  String? workingDirectory;
@override final  int? timeoutSeconds;

/// Create a copy of TestsValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TestsValidatorNodeConfigCopyWith<_TestsValidatorNodeConfig> get copyWith => __$TestsValidatorNodeConfigCopyWithImpl<_TestsValidatorNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TestsValidatorNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TestsValidatorNodeConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.args, _args)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,const DeepCollectionEquality().hash(_args),workingDirectory,timeoutSeconds);
}

@override
String toString() {
    return 'TestsValidatorNodeConfig(command: $command, args: $args, workingDirectory: $workingDirectory, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$TestsValidatorNodeConfigCopyWith<$Res> implements $TestsValidatorNodeConfigCopyWith<$Res> {
  factory _$TestsValidatorNodeConfigCopyWith(_TestsValidatorNodeConfig value, $Res Function(_TestsValidatorNodeConfig) _then) = __$TestsValidatorNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String command, List<String> args, String? workingDirectory, int? timeoutSeconds
});




}
/// @nodoc
class __$TestsValidatorNodeConfigCopyWithImpl<$Res>
    implements _$TestsValidatorNodeConfigCopyWith<$Res> {
  __$TestsValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final _TestsValidatorNodeConfig _self;
  final $Res Function(_TestsValidatorNodeConfig) _then;

/// Create a copy of TestsValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? args = null,Object? workingDirectory = freezed,Object? timeoutSeconds = freezed,}) {
  return _then(_TestsValidatorNodeConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ChecklistRule {

 String get label; ChecklistRuleKind get kind; String? get path; String? get command; String? get workingDirectory; String? get pattern;
/// Create a copy of ChecklistRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistRuleCopyWith<ChecklistRule> get copyWith => _$ChecklistRuleCopyWithImpl<ChecklistRule>(this as ChecklistRule, _$identity);

  /// Serializes this ChecklistRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChecklistRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistRule&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.workingDirectory, _this.workingDirectory) || other.workingDirectory == _this.workingDirectory)&&(identical(other.pattern, _this.pattern) || other.pattern == _this.pattern));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChecklistRule;
  return Object.hash(runtimeType,_this.label,_this.kind,_this.path,_this.command,_this.workingDirectory,_this.pattern);
}

@override
String toString() {
  final _this = this as ChecklistRule;
  return 'ChecklistRule(label: ${_this.label}, kind: ${_this.kind}, path: ${_this.path}, command: ${_this.command}, workingDirectory: ${_this.workingDirectory}, pattern: ${_this.pattern})';
}


}

/// @nodoc
abstract mixin class $ChecklistRuleCopyWith<$Res>  {
  factory $ChecklistRuleCopyWith(ChecklistRule value, $Res Function(ChecklistRule) _then) = _$ChecklistRuleCopyWithImpl;
@useResult
$Res call({
 String label, ChecklistRuleKind kind, String? path, String? command, String? workingDirectory, String? pattern
});




}
/// @nodoc
class _$ChecklistRuleCopyWithImpl<$Res>
    implements $ChecklistRuleCopyWith<$Res> {
  _$ChecklistRuleCopyWithImpl(this._self, this._then);

  final ChecklistRule _self;
  final $Res Function(ChecklistRule) _then;

/// Create a copy of ChecklistRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? kind = null,Object? path = freezed,Object? command = freezed,Object? workingDirectory = freezed,Object? pattern = freezed,}) {
  return _then(ChecklistRule(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChecklistRuleKind,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,pattern: freezed == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistRule].
extension ChecklistRulePatterns on ChecklistRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistRule value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistRule value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  ChecklistRuleKind kind,  String? path,  String? command,  String? workingDirectory,  String? pattern)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistRule() when $default != null:
return $default(_that.label,_that.kind,_that.path,_that.command,_that.workingDirectory,_that.pattern);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  ChecklistRuleKind kind,  String? path,  String? command,  String? workingDirectory,  String? pattern)  $default,) {final _that = this;
switch (_that) {
case _ChecklistRule():
return $default(_that.label,_that.kind,_that.path,_that.command,_that.workingDirectory,_that.pattern);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  ChecklistRuleKind kind,  String? path,  String? command,  String? workingDirectory,  String? pattern)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistRule() when $default != null:
return $default(_that.label,_that.kind,_that.path,_that.command,_that.workingDirectory,_that.pattern);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChecklistRule extends ChecklistRule {
  const _ChecklistRule({required this.label, required this.kind, this.path, this.command, this.workingDirectory, this.pattern}): super._();
  factory _ChecklistRule.fromJson(Map<String, dynamic> json) => _$ChecklistRuleFromJson(json);

@override final  String label;
@override final  ChecklistRuleKind kind;
@override final  String? path;
@override final  String? command;
@override final  String? workingDirectory;
@override final  String? pattern;

/// Create a copy of ChecklistRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistRuleCopyWith<_ChecklistRule> get copyWith => __$ChecklistRuleCopyWithImpl<_ChecklistRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChecklistRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistRule&&(identical(other.label, label) || other.label == label)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.path, path) || other.path == path)&&(identical(other.command, command) || other.command == command)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.pattern, pattern) || other.pattern == pattern));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,label,kind,path,command,workingDirectory,pattern);
}

@override
String toString() {
    return 'ChecklistRule(label: $label, kind: $kind, path: $path, command: $command, workingDirectory: $workingDirectory, pattern: $pattern)';
}


}

/// @nodoc
abstract mixin class _$ChecklistRuleCopyWith<$Res> implements $ChecklistRuleCopyWith<$Res> {
  factory _$ChecklistRuleCopyWith(_ChecklistRule value, $Res Function(_ChecklistRule) _then) = __$ChecklistRuleCopyWithImpl;
@override @useResult
$Res call({
 String label, ChecklistRuleKind kind, String? path, String? command, String? workingDirectory, String? pattern
});




}
/// @nodoc
class __$ChecklistRuleCopyWithImpl<$Res>
    implements _$ChecklistRuleCopyWith<$Res> {
  __$ChecklistRuleCopyWithImpl(this._self, this._then);

  final _ChecklistRule _self;
  final $Res Function(_ChecklistRule) _then;

/// Create a copy of ChecklistRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? kind = null,Object? path = freezed,Object? command = freezed,Object? workingDirectory = freezed,Object? pattern = freezed,}) {
  return _then(_ChecklistRule(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChecklistRuleKind,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,pattern: freezed == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ChecklistValidatorNodeConfig {

 List<ChecklistRule> get rules;
/// Create a copy of ChecklistValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistValidatorNodeConfigCopyWith<ChecklistValidatorNodeConfig> get copyWith => _$ChecklistValidatorNodeConfigCopyWithImpl<ChecklistValidatorNodeConfig>(this as ChecklistValidatorNodeConfig, _$identity);

  /// Serializes this ChecklistValidatorNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChecklistValidatorNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistValidatorNodeConfig&&const DeepCollectionEquality().equals(other.rules, _this.rules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChecklistValidatorNodeConfig;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.rules));
}

@override
String toString() {
  final _this = this as ChecklistValidatorNodeConfig;
  return 'ChecklistValidatorNodeConfig(rules: ${_this.rules})';
}


}

/// @nodoc
abstract mixin class $ChecklistValidatorNodeConfigCopyWith<$Res>  {
  factory $ChecklistValidatorNodeConfigCopyWith(ChecklistValidatorNodeConfig value, $Res Function(ChecklistValidatorNodeConfig) _then) = _$ChecklistValidatorNodeConfigCopyWithImpl;
@useResult
$Res call({
 List<ChecklistRule> rules
});




}
/// @nodoc
class _$ChecklistValidatorNodeConfigCopyWithImpl<$Res>
    implements $ChecklistValidatorNodeConfigCopyWith<$Res> {
  _$ChecklistValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final ChecklistValidatorNodeConfig _self;
  final $Res Function(ChecklistValidatorNodeConfig) _then;

/// Create a copy of ChecklistValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rules = null,}) {
  return _then(ChecklistValidatorNodeConfig(
rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<ChecklistRule>,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistValidatorNodeConfig].
extension ChecklistValidatorNodeConfigPatterns on ChecklistValidatorNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistValidatorNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistValidatorNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistValidatorNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ChecklistRule> rules)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig() when $default != null:
return $default(_that.rules);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ChecklistRule> rules)  $default,) {final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig():
return $default(_that.rules);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ChecklistRule> rules)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistValidatorNodeConfig() when $default != null:
return $default(_that.rules);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChecklistValidatorNodeConfig extends ChecklistValidatorNodeConfig {
  const _ChecklistValidatorNodeConfig({required  List<ChecklistRule> rules}): _rules = rules,super._();
  factory _ChecklistValidatorNodeConfig.fromJson(Map<String, dynamic> json) => _$ChecklistValidatorNodeConfigFromJson(json);

 final  List<ChecklistRule> _rules;
@override List<ChecklistRule> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}


/// Create a copy of ChecklistValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistValidatorNodeConfigCopyWith<_ChecklistValidatorNodeConfig> get copyWith => __$ChecklistValidatorNodeConfigCopyWithImpl<_ChecklistValidatorNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChecklistValidatorNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistValidatorNodeConfig&&const DeepCollectionEquality().equals(other.rules, _rules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_rules));
}

@override
String toString() {
    return 'ChecklistValidatorNodeConfig(rules: $rules)';
}


}

/// @nodoc
abstract mixin class _$ChecklistValidatorNodeConfigCopyWith<$Res> implements $ChecklistValidatorNodeConfigCopyWith<$Res> {
  factory _$ChecklistValidatorNodeConfigCopyWith(_ChecklistValidatorNodeConfig value, $Res Function(_ChecklistValidatorNodeConfig) _then) = __$ChecklistValidatorNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 List<ChecklistRule> rules
});




}
/// @nodoc
class __$ChecklistValidatorNodeConfigCopyWithImpl<$Res>
    implements _$ChecklistValidatorNodeConfigCopyWith<$Res> {
  __$ChecklistValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final _ChecklistValidatorNodeConfig _self;
  final $Res Function(_ChecklistValidatorNodeConfig) _then;

/// Create a copy of ChecklistValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rules = null,}) {
  return _then(_ChecklistValidatorNodeConfig(
rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<ChecklistRule>,
  ));
}


}


/// @nodoc
mixin _$ReviewValidatorNodeConfig {

 String get harnessType; String? get agentId; String? get reviewCriteria; int? get timeoutSeconds;
/// Create a copy of ReviewValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewValidatorNodeConfigCopyWith<ReviewValidatorNodeConfig> get copyWith => _$ReviewValidatorNodeConfigCopyWithImpl<ReviewValidatorNodeConfig>(this as ReviewValidatorNodeConfig, _$identity);

  /// Serializes this ReviewValidatorNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReviewValidatorNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewValidatorNodeConfig&&(identical(other.harnessType, _this.harnessType) || other.harnessType == _this.harnessType)&&(identical(other.agentId, _this.agentId) || other.agentId == _this.agentId)&&(identical(other.reviewCriteria, _this.reviewCriteria) || other.reviewCriteria == _this.reviewCriteria)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewValidatorNodeConfig;
  return Object.hash(runtimeType,_this.harnessType,_this.agentId,_this.reviewCriteria,_this.timeoutSeconds);
}

@override
String toString() {
  final _this = this as ReviewValidatorNodeConfig;
  return 'ReviewValidatorNodeConfig(harnessType: ${_this.harnessType}, agentId: ${_this.agentId}, reviewCriteria: ${_this.reviewCriteria}, timeoutSeconds: ${_this.timeoutSeconds})';
}


}

/// @nodoc
abstract mixin class $ReviewValidatorNodeConfigCopyWith<$Res>  {
  factory $ReviewValidatorNodeConfigCopyWith(ReviewValidatorNodeConfig value, $Res Function(ReviewValidatorNodeConfig) _then) = _$ReviewValidatorNodeConfigCopyWithImpl;
@useResult
$Res call({
 String harnessType, String? agentId, String? reviewCriteria, int? timeoutSeconds
});




}
/// @nodoc
class _$ReviewValidatorNodeConfigCopyWithImpl<$Res>
    implements $ReviewValidatorNodeConfigCopyWith<$Res> {
  _$ReviewValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final ReviewValidatorNodeConfig _self;
  final $Res Function(ReviewValidatorNodeConfig) _then;

/// Create a copy of ReviewValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? harnessType = null,Object? agentId = freezed,Object? reviewCriteria = freezed,Object? timeoutSeconds = freezed,}) {
  return _then(ReviewValidatorNodeConfig(
harnessType: null == harnessType ? _self.harnessType : harnessType // ignore: cast_nullable_to_non_nullable
as String,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,reviewCriteria: freezed == reviewCriteria ? _self.reviewCriteria : reviewCriteria // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewValidatorNodeConfig].
extension ReviewValidatorNodeConfigPatterns on ReviewValidatorNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewValidatorNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewValidatorNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewValidatorNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String harnessType,  String? agentId,  String? reviewCriteria,  int? timeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig() when $default != null:
return $default(_that.harnessType,_that.agentId,_that.reviewCriteria,_that.timeoutSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String harnessType,  String? agentId,  String? reviewCriteria,  int? timeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig():
return $default(_that.harnessType,_that.agentId,_that.reviewCriteria,_that.timeoutSeconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String harnessType,  String? agentId,  String? reviewCriteria,  int? timeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _ReviewValidatorNodeConfig() when $default != null:
return $default(_that.harnessType,_that.agentId,_that.reviewCriteria,_that.timeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewValidatorNodeConfig extends ReviewValidatorNodeConfig {
  const _ReviewValidatorNodeConfig({required this.harnessType, this.agentId, this.reviewCriteria, this.timeoutSeconds}): super._();
  factory _ReviewValidatorNodeConfig.fromJson(Map<String, dynamic> json) => _$ReviewValidatorNodeConfigFromJson(json);

@override final  String harnessType;
@override final  String? agentId;
@override final  String? reviewCriteria;
@override final  int? timeoutSeconds;

/// Create a copy of ReviewValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewValidatorNodeConfigCopyWith<_ReviewValidatorNodeConfig> get copyWith => __$ReviewValidatorNodeConfigCopyWithImpl<_ReviewValidatorNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewValidatorNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewValidatorNodeConfig&&(identical(other.harnessType, harnessType) || other.harnessType == harnessType)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.reviewCriteria, reviewCriteria) || other.reviewCriteria == reviewCriteria)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,harnessType,agentId,reviewCriteria,timeoutSeconds);
}

@override
String toString() {
    return 'ReviewValidatorNodeConfig(harnessType: $harnessType, agentId: $agentId, reviewCriteria: $reviewCriteria, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$ReviewValidatorNodeConfigCopyWith<$Res> implements $ReviewValidatorNodeConfigCopyWith<$Res> {
  factory _$ReviewValidatorNodeConfigCopyWith(_ReviewValidatorNodeConfig value, $Res Function(_ReviewValidatorNodeConfig) _then) = __$ReviewValidatorNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String harnessType, String? agentId, String? reviewCriteria, int? timeoutSeconds
});




}
/// @nodoc
class __$ReviewValidatorNodeConfigCopyWithImpl<$Res>
    implements _$ReviewValidatorNodeConfigCopyWith<$Res> {
  __$ReviewValidatorNodeConfigCopyWithImpl(this._self, this._then);

  final _ReviewValidatorNodeConfig _self;
  final $Res Function(_ReviewValidatorNodeConfig) _then;

/// Create a copy of ReviewValidatorNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? harnessType = null,Object? agentId = freezed,Object? reviewCriteria = freezed,Object? timeoutSeconds = freezed,}) {
  return _then(_ReviewValidatorNodeConfig(
harnessType: null == harnessType ? _self.harnessType : harnessType // ignore: cast_nullable_to_non_nullable
as String,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,reviewCriteria: freezed == reviewCriteria ? _self.reviewCriteria : reviewCriteria // ignore: cast_nullable_to_non_nullable
as String?,timeoutSeconds: freezed == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$HumanApprovalNodeConfig {

 String get instructions; String? get title; bool get allowFeedback;
/// Create a copy of HumanApprovalNodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HumanApprovalNodeConfigCopyWith<HumanApprovalNodeConfig> get copyWith => _$HumanApprovalNodeConfigCopyWithImpl<HumanApprovalNodeConfig>(this as HumanApprovalNodeConfig, _$identity);

  /// Serializes this HumanApprovalNodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HumanApprovalNodeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HumanApprovalNodeConfig&&(identical(other.instructions, _this.instructions) || other.instructions == _this.instructions)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.allowFeedback, _this.allowFeedback) || other.allowFeedback == _this.allowFeedback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HumanApprovalNodeConfig;
  return Object.hash(runtimeType,_this.instructions,_this.title,_this.allowFeedback);
}

@override
String toString() {
  final _this = this as HumanApprovalNodeConfig;
  return 'HumanApprovalNodeConfig(instructions: ${_this.instructions}, title: ${_this.title}, allowFeedback: ${_this.allowFeedback})';
}


}

/// @nodoc
abstract mixin class $HumanApprovalNodeConfigCopyWith<$Res>  {
  factory $HumanApprovalNodeConfigCopyWith(HumanApprovalNodeConfig value, $Res Function(HumanApprovalNodeConfig) _then) = _$HumanApprovalNodeConfigCopyWithImpl;
@useResult
$Res call({
 String instructions, String? title, bool allowFeedback
});




}
/// @nodoc
class _$HumanApprovalNodeConfigCopyWithImpl<$Res>
    implements $HumanApprovalNodeConfigCopyWith<$Res> {
  _$HumanApprovalNodeConfigCopyWithImpl(this._self, this._then);

  final HumanApprovalNodeConfig _self;
  final $Res Function(HumanApprovalNodeConfig) _then;

/// Create a copy of HumanApprovalNodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? instructions = null,Object? title = freezed,Object? allowFeedback = null,}) {
  return _then(HumanApprovalNodeConfig(
instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,allowFeedback: null == allowFeedback ? _self.allowFeedback : allowFeedback // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HumanApprovalNodeConfig].
extension HumanApprovalNodeConfigPatterns on HumanApprovalNodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HumanApprovalNodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HumanApprovalNodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HumanApprovalNodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String instructions,  String? title,  bool allowFeedback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig() when $default != null:
return $default(_that.instructions,_that.title,_that.allowFeedback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String instructions,  String? title,  bool allowFeedback)  $default,) {final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig():
return $default(_that.instructions,_that.title,_that.allowFeedback);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String instructions,  String? title,  bool allowFeedback)?  $default,) {final _that = this;
switch (_that) {
case _HumanApprovalNodeConfig() when $default != null:
return $default(_that.instructions,_that.title,_that.allowFeedback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HumanApprovalNodeConfig extends HumanApprovalNodeConfig {
  const _HumanApprovalNodeConfig({required this.instructions, this.title, this.allowFeedback = true}): super._();
  factory _HumanApprovalNodeConfig.fromJson(Map<String, dynamic> json) => _$HumanApprovalNodeConfigFromJson(json);

@override final  String instructions;
@override final  String? title;
@override@JsonKey() final  bool allowFeedback;

/// Create a copy of HumanApprovalNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HumanApprovalNodeConfigCopyWith<_HumanApprovalNodeConfig> get copyWith => __$HumanApprovalNodeConfigCopyWithImpl<_HumanApprovalNodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HumanApprovalNodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HumanApprovalNodeConfig&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.title, title) || other.title == title)&&(identical(other.allowFeedback, allowFeedback) || other.allowFeedback == allowFeedback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,instructions,title,allowFeedback);
}

@override
String toString() {
    return 'HumanApprovalNodeConfig(instructions: $instructions, title: $title, allowFeedback: $allowFeedback)';
}


}

/// @nodoc
abstract mixin class _$HumanApprovalNodeConfigCopyWith<$Res> implements $HumanApprovalNodeConfigCopyWith<$Res> {
  factory _$HumanApprovalNodeConfigCopyWith(_HumanApprovalNodeConfig value, $Res Function(_HumanApprovalNodeConfig) _then) = __$HumanApprovalNodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String instructions, String? title, bool allowFeedback
});




}
/// @nodoc
class __$HumanApprovalNodeConfigCopyWithImpl<$Res>
    implements _$HumanApprovalNodeConfigCopyWith<$Res> {
  __$HumanApprovalNodeConfigCopyWithImpl(this._self, this._then);

  final _HumanApprovalNodeConfig _self;
  final $Res Function(_HumanApprovalNodeConfig) _then;

/// Create a copy of HumanApprovalNodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? instructions = null,Object? title = freezed,Object? allowFeedback = null,}) {
  return _then(_HumanApprovalNodeConfig(
instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,allowFeedback: null == allowFeedback ? _self.allowFeedback : allowFeedback // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
