import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// A single field-level validation problem in a node's `config` map.
@immutable
final class NodeConfigIssue {
  /// Creates a node configuration validation issue.
  const new({required this.field, required this.message});

  /// Dot- or bracket-qualified config field path (for example
  /// `workingDirectory` or `rules[0].command`).
  final String field;

  /// Human-readable description of the validation problem.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeConfigIssue &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          message == other.message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => 'NodeConfigIssue($field: $message)';
}

final RegExp _windowsDrivePrefix = RegExp('^[a-zA-Z]:');

/// Returns `true` when [value] is `null` or contains only whitespace.
bool isBlank(String? value) => value == null || value.trim().isEmpty;

/// Adds an issue when [path] (when non-blank) has an empty dot segment.
void validateDotPath(
  String? path, {
  required String field,
  required List<NodeConfigIssue> issues,
}) {
  if (isBlank(path)) {
    return;
  }
  if (path!.trim().split('.').any((s) => s.isEmpty)) {
    issues.add(
      NodeConfigIssue(
        field: field,
        message: 'Must be a dot path with no empty segment.',
      ),
    );
  }
}

/// Validates that [path] (when non-null) is a safe relative path within the
/// workspace (no leading slash/backslash, no Windows drive prefix, no `..`
/// traversal segments, and no null bytes).
void validateRelativePath(
  String? path, {
  required String field,
  required List<NodeConfigIssue> issues,
  bool required = false,
}) {
  if (path == null) {
    if (required) {
      issues.add(
        NodeConfigIssue(field: field, message: 'Must not be missing.'),
      );
    }
    return;
  }

  if (path.trim().isEmpty) {
    issues.add(NodeConfigIssue(field: field, message: 'Must not be blank.'));
    return;
  }

  if (path.contains('\x00')) {
    issues.add(
      NodeConfigIssue(field: field, message: 'Must not contain null bytes.'),
    );
    return;
  }

  if (path.startsWith('/') ||
      path.startsWith(r'\') ||
      _windowsDrivePrefix.hasMatch(path)) {
    issues.add(
      NodeConfigIssue(
        field: field,
        message: 'Must be a relative path, not an absolute path.',
      ),
    );
    return;
  }

  final segments = path.split(RegExp(r'[/\\]'));
  if (segments.any((segment) => segment == '..')) {
    issues.add(
      NodeConfigIssue(
        field: field,
        message: 'Must not contain ".." path traversal segments.',
      ),
    );
  }
}

/// Validates that [value] (when non-null) is strictly positive (`> 0`).
void validatePositiveInt(
  int? value, {
  required String field,
  required List<NodeConfigIssue> issues,
}) {
  if (value != null && value <= 0) {
    issues.add(
      NodeConfigIssue(field: field, message: 'Must be greater than 0.'),
    );
  }
}

/// Names of config fields a harness descriptor may leave undeclared, with the
/// noun used in the refusal message.
const Map<String, String> guardedHarnessFields = {
  'model': 'a model',
  'effort': 'an effort',
};

/// Adds an issue for each guarded field set to a non-blank value in [raw] that
/// is not among [declaredFieldNames].
void validateUndeclaredHarnessFields(
  JsonMap raw, {
  required String typeId,
  required Set<String> declaredFieldNames,
  required List<NodeConfigIssue> issues,
}) {
  for (final entry in guardedHarnessFields.entries) {
    if (declaredFieldNames.contains(entry.key)) {
      continue;
    }
    final value = raw[entry.key];
    if (value == null || (value is String && isBlank(value))) {
      continue;
    }
    issues.add(
      NodeConfigIssue(
        field: entry.key,
        message: '$typeId does not support choosing ${entry.value}.',
      ),
    );
  }
}

/// Decodes [raw] using [fromJson] and runs [validate], returning any
/// [FormatException] as a [NodeConfigIssue] on `config`.
List<NodeConfigIssue> validateTypedConfig<T>(
  JsonMap raw,
  T Function(JsonMap) fromJson,
  List<NodeConfigIssue> Function(T config) validate,
) {
  try {
    final parsed = fromJson(raw);
    return validate(parsed);
  } on FormatException catch (e) {
    return [NodeConfigIssue(field: 'config', message: e.message)];
  }
}
