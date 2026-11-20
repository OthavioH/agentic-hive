/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Reads [key] from [json] as a [T], or throws a [FormatException] that names
/// the field.
///
/// A nullable [T] accepts a missing key or a `null` value.
T readField<T>(JsonMap json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('Expected "$key" to be $T, got ${value.runtimeType}.');
}

/// Reads [key] from [json] as a nested JSON object.
JsonMap readObject(JsonMap json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException(
    'Expected "$key" to be a JSON object, got ${value.runtimeType}.',
  );
}
