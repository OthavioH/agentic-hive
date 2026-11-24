import 'dart:convert';

import 'package:json_schema/json_schema.dart';

/// JSON Schema checks for approval proposals (spec #129).
abstract final class ProposalSchema {
  /// Returns problems with [schemaText] as a schema; empty when it is a
  /// valid, compilable JSON Schema.
  static List<String> checkSchema(String schemaText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(schemaText);
    } on FormatException catch (e) {
      return ['Not valid JSON: ${e.message}'];
    }
    if (decoded is! Map && decoded is! bool) {
      return ['Not a valid JSON Schema: a schema must be a JSON object.'];
    }
    try {
      JsonSchema.create(decoded!);
    } on Object catch (e) {
      return ['Not a valid JSON Schema: $e'];
    }
    return const [];
  }

  /// Returns the validation errors of [value] against [schemaText]; empty
  /// when valid. An uncompilable schema yields one message instead of
  /// throwing.
  static List<String> validate({
    required String schemaText,
    required Object? value,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(schemaText);
    } on FormatException catch (e) {
      return ['Not valid JSON: ${e.message}'];
    }
    if (decoded is! Map && decoded is! bool) {
      return ['Not a valid JSON Schema: a schema must be a JSON object.'];
    }
    final JsonSchema schema;
    try {
      schema = JsonSchema.create(decoded!);
    } on Object catch (e) {
      return ['Not a valid JSON Schema: $e'];
    }
    final result = schema.validate(value);
    return [
      for (final error in result.errors)
        '${error.instancePath}: ${error.message}',
    ];
  }
}
