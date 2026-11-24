import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Result of checking the human's edited proposal text.
sealed class ProposalDraftCheck {
  /// Creates a [ProposalDraftCheck].
  const new();
}

/// Valid edited proposal JSON decoded to [value].
final class ProposalDraftValid extends ProposalDraftCheck {
  /// Creates a [ProposalDraftValid] holding [value].
  const new(this.value);

  /// Decoded JSON value.
  final Object? value;
}

/// Invalid edited proposal JSON or schema validation failure.
final class ProposalDraftInvalid extends ProposalDraftCheck {
  /// Creates a [ProposalDraftInvalid] with up to 5 error [messages].
  const new(this.messages);

  /// Validation error messages, non-empty and capped at 5 entries.
  final List<String> messages;
}

/// Parses `text` as JSON and validates it against `schemaText` when set.
final class ValidateProposalDraft {
  /// Creates a [ValidateProposalDraft].
  const new();

  static const int _maxErrors = 5;

  /// Validates [text] as JSON and, when [schemaText] is non-blank, against
  /// that JSON Schema.
  ProposalDraftCheck call({required String text, String? schemaText}) {
    if (text.trim().isEmpty) {
      return const ProposalDraftInvalid(<String>['Not valid JSON: empty']);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      return ProposalDraftInvalid(<String>['Not valid JSON: ${e.message}']);
    }
    if (schemaText != null && schemaText.trim().isNotEmpty) {
      final errors = ProposalSchema.validate(
        schemaText: schemaText,
        value: decoded,
      );
      if (errors.isNotEmpty) {
        return ProposalDraftInvalid(
          errors.take(_maxErrors).toList(growable: false),
        );
      }
    }
    return ProposalDraftValid(decoded);
  }
}
