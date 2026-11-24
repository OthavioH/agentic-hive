/// High-level grouping for workflow node types.
enum NodeCategory {
  /// Agent harness nodes (`harness.*`).
  harnesses,

  /// Direct command execution nodes (`command`).
  execution,

  /// Automated validation nodes (`validator.*`).
  validators,

  /// Human-in-the-loop pause/approval nodes (`human_approval`).
  human,
}

/// Canonical `WorkflowNode.type` identifiers.
abstract final class NodeTypeId {
  /// Claude Code headless harness (`claude -p`).
  static const String claudeCode = 'harness.claude_code';

  /// OpenAI Codex headless harness (`codex exec`).
  static const String codex = 'harness.codex';

  /// Gemini CLI headless harness (`gemini -p`).
  static const String geminiCli = 'harness.gemini_cli';

  /// Antigravity CLI headless harness (`agy -p`).
  static const String antigravity = 'harness.antigravity';

  /// Generic interactive PTY harness fallback.
  static const String terminal = 'harness.terminal';

  /// Direct shell/process command execution node.
  static const String command = 'command';

  /// Deterministic test-runner validator node.
  static const String testsValidator = 'validator.tests';

  /// Deterministic rule-based checklist validator node.
  static const String checklistValidator = 'validator.checklist';

  /// Headless harness-backed review validator node.
  static const String reviewValidator = 'validator.review';

  /// Human approval pause node.
  static const String humanApproval = 'human_approval';

  /// Fan-out node: starts one child run per item of a list.
  static const String fanOut = 'fan_out';
}

/// Standard edge output labels emitted by nodes.
abstract final class NodeOutput {
  /// Emitted when a node completes successfully.
  static const String onSuccess = 'onSuccess';

  /// Emitted when a node fails its task or check.
  static const String onFailure = 'onFailure';

  /// Emitted when a review or human approval is approved.
  static const String approved = 'approved';

  /// Emitted when a human approval is rejected.
  static const String rejected = 'rejected';

  /// Emitted when a review validator requests changes.
  static const String changesRequested = 'changesRequested';
}
