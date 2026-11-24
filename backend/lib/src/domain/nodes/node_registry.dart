import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/nodes/fan_out_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/command_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/human_approval_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/validator_nodes.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Factory function instantiating a [Node].
typedef NodeFactory = Node Function();

final class _RegistryEntry {
  const new({required this.descriptor, required this.factory});

  final NodeDescriptor descriptor;
  final NodeFactory factory;
}

/// Registry mapping canonical `WorkflowNode.type` identifiers to their
/// [NodeDescriptor] and [Node] factory (ADR 0006).
final class NodeRegistry {
  /// Creates an empty node registry.
  new();

  /// Creates a registry populated with all 11 canonical node types.
  ///
  /// [executionSettings] and [childRuns] are resolved lazily, when a node is
  /// created, so they can be registered after the registry.
  factory withDefaults({
    required NodeProcessRunner processRunner,
    required PtyRunner ptyRunner,
    required DefaultShellProvider defaultShellProvider,
    required ResultContract resultContract,
    required HumanApprovalPort approvalPort,
    required AgentPromptResolver agentPromptResolver,
    required ChildRunPort Function() childRuns,
    ProcessTreeKiller? processTreeKiller,
    ExecutionSettingsService Function()? executionSettings,
  }) {
    final registry = NodeRegistry();
    registry
      ..register(
        NodeDescriptors.claudeCode,
        () => ClaudeCodeNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
      )
      ..register(
        NodeDescriptors.codex,
        () => CodexNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
      )
      ..register(
        NodeDescriptors.geminiCli,
        () => GeminiCliNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
      )
      ..register(
        NodeDescriptors.antigravity,
        () => AntigravityNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
      )
      ..register(
        NodeDescriptors.terminal,
        () => TerminalHarnessNode(
          ptyRunner: ptyRunner,
          defaultShellProvider: defaultShellProvider,
          executionSettings: executionSettings?.call(),
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
          processTreeKiller: processTreeKiller,
        ),
      )
      ..register(
        NodeDescriptors.command,
        () => CommandNode(processRunner: processRunner),
      )
      ..register(
        NodeDescriptors.testsValidator,
        () => TestsValidatorNode(processRunner: processRunner),
      )
      ..register(
        NodeDescriptors.checklistValidator,
        () => ChecklistValidatorNode(processRunner: processRunner),
      )
      ..register(
        NodeDescriptors.reviewValidator,
        () => ReviewValidatorNode(resolveNode: registry.create),
      )
      ..register(
        NodeDescriptors.humanApproval,
        () => HumanApprovalNode(approvalPort: approvalPort),
      )
      ..register(
        NodeDescriptors.fanOut,
        () => FanOutNode(childRuns: childRuns()),
      );
    return registry;
  }

  final Map<String, _RegistryEntry> _entries = <String, _RegistryEntry>{};

  /// Registers [descriptor] and [factory]; throws [StateError] on duplicate
  /// `typeId`.
  void register(NodeDescriptor descriptor, NodeFactory factory) {
    if (_entries.containsKey(descriptor.typeId)) {
      throw StateError(
        'Node type "${descriptor.typeId}" is already registered.',
      );
    }
    _entries[descriptor.typeId] = _RegistryEntry(
      descriptor: descriptor,
      factory: factory,
    );
  }

  /// Whether [typeId] is registered.
  bool contains(String typeId) => _entries.containsKey(typeId);

  /// All registered descriptors in registration order.
  List<NodeDescriptor> get descriptors =>
      _entries.values.map((e) => e.descriptor).toList(growable: false);

  /// Returns the [NodeDescriptor] for [typeId], or `null` if unknown.
  NodeDescriptor? descriptorFor(String typeId) => _entries[typeId]?.descriptor;

  /// Creates a [Node] for [typeId], or returns [NotFoundFailure] if unknown.
  Result<Node> create(String typeId) {
    final entry = _entries[typeId];
    if (entry == null) {
      return FailureResult(NotFoundFailure('Unknown node type "$typeId".'));
    }
    return Success(entry.factory());
  }

  /// Creates a [Node] for [typeId], or returns `null` if unknown.
  Node? createOrNull(String typeId) => _entries[typeId]?.factory();
}
