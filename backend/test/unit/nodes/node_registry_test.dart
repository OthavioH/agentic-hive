import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/nodes/unconfigured_node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/command_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/human_approval_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/validator_nodes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _NoopProcessRunner implements NodeProcessRunner {
  const new();

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async => const Success(ProcessExecutionResult(exitCode: 0));
}

void main() {
  group('NodeRegistry', () {
    late NodeRegistry registry;

    setUp(() {
      registry = NodeRegistry.withDefaults(
        processRunner: const _NoopProcessRunner(),
        ptyRunner: const UnconfiguredPtyRunner(),
        resultContract: const UnconfiguredResultContract(),
        approvalPort: const UnconfiguredHumanApprovalPort(),
        agentPromptResolver: const UnconfiguredAgentPromptResolver(),
      );
    });

    test('registers all 10 canonical node types', () {
      expect(registry.descriptors, hasLength(10));
      for (final descriptor in NodeDescriptors.all) {
        expect(registry.contains(descriptor.typeId), isTrue);
        expect(registry.descriptorFor(descriptor.typeId), same(descriptor));
        expect(registry.create(descriptor.typeId).isSuccess, isTrue);
      }

      expect(
        registry.create(NodeTypeId.claudeCode).valueOrNull,
        isA<ClaudeCodeNode>(),
      );
      expect(registry.create(NodeTypeId.codex).valueOrNull, isA<CodexNode>());
      expect(
        registry.create(NodeTypeId.geminiCli).valueOrNull,
        isA<GeminiCliNode>(),
      );
      expect(
        registry.create(NodeTypeId.antigravity).valueOrNull,
        isA<AntigravityNode>(),
      );
      expect(
        registry.create(NodeTypeId.terminal).valueOrNull,
        isA<TerminalHarnessNode>(),
      );
      expect(
        registry.create(NodeTypeId.command).valueOrNull,
        isA<CommandNode>(),
      );
      expect(
        registry.create(NodeTypeId.testsValidator).valueOrNull,
        isA<TestsValidatorNode>(),
      );
      expect(
        registry.create(NodeTypeId.checklistValidator).valueOrNull,
        isA<ChecklistValidatorNode>(),
      );
      expect(
        registry.create(NodeTypeId.reviewValidator).valueOrNull,
        isA<ReviewValidatorNode>(),
      );
      expect(
        registry.create(NodeTypeId.humanApproval).valueOrNull,
        isA<HumanApprovalNode>(),
      );
    });

    test('guards against duplicate registration', () {
      expect(
        () => registry.register(
          NodeDescriptors.command,
          () => const CommandNode(processRunner: _NoopProcessRunner()),
        ),
        throwsStateError,
      );
    });

    test('returns NotFoundFailure and null on unknown type', () {
      final result = registry.create('unknown.node');
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(registry.createOrNull('unknown.node'), isNull);
      expect(registry.descriptorFor('unknown.node'), isNull);
    });
  });
}
