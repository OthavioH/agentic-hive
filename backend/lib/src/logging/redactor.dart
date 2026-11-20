/// Removes secrets from everything that is about to be logged.
///
/// Secrets must never appear in a log at any level. Two layers enforce it:
/// - values of fields whose name looks sensitive are replaced;
/// - known secret values and `Bearer` credentials are replaced inside text.
final class Redactor {
  /// Creates a redactor that also hides each of [secrets].
  new({Iterable<String> secrets = const []}) {
    secrets.forEach(addSecret);
  }

  /// What replaces a redacted value.
  static const placeholder = '[REDACTED]';

  static final _sensitiveKey = RegExp(
    'token|secret|password|passwd|authorization|api[_-]?key|cookie|'
    'credential',
    caseSensitive: false,
  );

  static final _bearer = RegExp(r'(Bearer\s+)[^\s"]+', caseSensitive: false);

  final _secrets = <String>{};

  /// Registers a value that must never be logged, such as a generated key.
  void addSecret(String secret) {
    if (secret.isNotEmpty) _secrets.add(secret);
  }

  /// Whether a field named [key] must have its value hidden.
  bool isSensitiveKey(String key) => _sensitiveKey.hasMatch(key);

  /// Hides `Bearer` credentials and registered secrets inside [text].
  String redactText(String text) {
    var result = text.replaceAllMapped(
      _bearer,
      (match) => '${match[1]}$placeholder',
    );
    for (final secret in _secrets) {
      result = result.replaceAll(secret, placeholder);
    }
    return result;
  }

  /// Redacts [value] of the field named [key], recursing into maps and lists.
  Object? redactValue(String key, Object? value) {
    if (isSensitiveKey(key)) return placeholder;
    return switch (value) {
      null || num() || bool() => value,
      String() => redactText(value),
      Map() => redactFields(value.map((k, v) => MapEntry('$k', v))),
      Iterable() => [for (final item in value) redactValue(key, item)],
      _ => redactText(value.toString()),
    };
  }

  /// Redacts every field of [fields].
  Map<String, Object?> redactFields(Map<String, Object?> fields) => {
    for (final entry in fields.entries)
      entry.key: redactValue(entry.key, entry.value),
  };
}
