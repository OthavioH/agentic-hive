import 'package:json_annotation/json_annotation.dart';

/// Supported concrete CLI harnesses.
enum HarnessId {
  /// Claude Code CLI (`claude`).
  @JsonValue('claude_code')
  claudeCode('claude_code', 'Claude Code'),

  /// OpenAI Codex CLI (`codex`).
  @JsonValue('codex')
  codex('codex', 'Codex'),

  /// Google Gemini CLI (`gemini`).
  @JsonValue('gemini_cli')
  geminiCli('gemini_cli', 'Gemini CLI'),

  /// Antigravity CLI (`agy`).
  @JsonValue('antigravity')
  antigravity('antigravity', 'Antigravity');

  new(this.wireName, this.displayName);

  /// Wire identifier used in JSON and URL paths (for example `claude_code`).
  final String wireName;

  /// Human-readable display name (for example `Claude Code`).
  final String displayName;

  /// Returns the [HarnessId] matching [wireName], or `null` if unknown.
  static HarnessId? tryParse(String wireName) {
    for (final id in values) {
      if (id.wireName == wireName) return id;
    }
    return null;
  }
}
