import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/result_contract/hive_result_contract.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String dataDir;
  late String workspacePath;
  late ResultContractCoordinator coordinator;
  late HiveResultContract contract;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_rc_');
    dataDir = p.join(tempDir.path, 'data');
    workspacePath = p.join(tempDir.path, 'workspace');
    await Directory(dataDir).create(recursive: true);
    await Directory(workspacePath).create(recursive: true);

    coordinator = ResultContractCoordinator();
    contract = HiveResultContract(
      coordinator: coordinator,
      dataDir: dataDir,
      socketPath: p.join(dataDir, 'backend.sock'),
      mcpLocator: HiveMcpLocator(
        overrideCommand: const HiveMcpLaunchCommand(executable: 'hive-mcp'),
      ),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  NodeExecutionContext makeContext({
    String runId = 'run-1',
    String nodeId = 'node-1',
    int attempt = 1,
    List<String> availableOutputs = const <String>[
      NodeOutput.onSuccess,
      NodeOutput.onFailure,
    ],
  }) => NodeExecutionContext(
    runId: runId,
    nodeId: nodeId,
    targetFolder: workspacePath,
    attempt: attempt,
    availableOutputs: availableOutputs,
  );

  group('HiveResultContract', () {
    test('stores fallback result.json outside the workspace', () {
      final fallback = contract.fallbackResultJsonPath(
        runId: 'run-42',
        nodeId: 'coder',
        attempt: 2,
      );

      expect(p.isWithin(dataDir, fallback), isTrue);
      expect(p.isWithin(workspacePath, fallback), isFalse);
      expect(
        fallback,
        endsWith(p.join('runs', 'run-42', 'results', 'coder-attempt-2.json')),
      );
    });

    test(
      'openSession creates temporary MCP config and dispose removes it',
      () async {
        final ctx = makeContext();
        final session = (await contract.openSession(ctx)).valueOrNull!;

        final configFile = File(session.mcpConfigPath);
        expect(configFile.existsSync(), isTrue);

        final decoded =
            jsonDecode(await configFile.readAsString()) as Map<String, Object?>;
        final servers = decoded['mcpServers']! as Map<String, Object?>;
        final hive = servers['hive']! as Map<String, Object?>;
        expect(hive['command'], 'hive-mcp');
        expect(hive['args'], containsAllInOrder(<String>['--run-id', 'run-1']));

        await session.dispose();
        expect(configFile.existsSync(), isFalse);
      },
    );

    test(
      'instructionsFor documents report_result, ask_human, allowed statuses, '
      'and fallback path',
      () {
        final ctx = makeContext(
          availableOutputs: const <String>[
            NodeOutput.approved,
            NodeOutput.changesRequested,
          ],
        );

        final instructions = contract.instructionsFor(ctx);
        expect(instructions, contains('report_result'));
        expect(instructions, contains('ask_human'));
        expect(instructions, contains('"approved"'));
        expect(instructions, contains('"changesRequested"'));
        expect(
          instructions,
          contains(
            contract.fallbackResultJsonPath(runId: 'run-1', nodeId: 'node-1'),
          ),
        );
      },
    );

    test(
      'allows retry after validation error, then locks first valid MCP report',
      () async {
        final ctx = makeContext();
        final session = (await contract.openSession(ctx)).valueOrNull!;
        addTearDown(session.dispose);

        final invalid = coordinator.submitMcpReport(
          runId: 'run-1',
          nodeId: 'node-1',
          attempt: 1,
          payload: const <String, Object?>{'status': 'bogus', 'summary': 'bad'},
        );
        expect(invalid.failureOrNull, isA<ValidationFailure>());

        final valid = coordinator.submitMcpReport(
          runId: 'run-1',
          nodeId: 'node-1',
          attempt: 1,
          payload: const <String, Object?>{
            'status': 'onSuccess',
            'summary': 'Fixed and verified.',
          },
        );
        expect(valid.isSuccess, isTrue);

        final duplicate = coordinator.submitMcpReport(
          runId: 'run-1',
          nodeId: 'node-1',
          attempt: 1,
          payload: const <String, Object?>{
            'status': 'onFailure',
            'summary': 'Should not overwrite.',
          },
        );
        expect(duplicate.failureOrNull, isA<ConflictFailure>());

        final read = await contract.readReport(ctx);
        expect(read.valueOrNull?.status, ResultContractStatus.success);
        expect(read.valueOrNull?.summary, 'Fixed and verified.');
      },
    );

    test('MCP report takes precedence over result.json', () async {
      final ctx = makeContext();
      final session = (await contract.openSession(ctx)).valueOrNull!;
      addTearDown(session.dispose);

      await File(session.resultJsonPath).writeAsString(
        jsonEncode(const <String, Object?>{
          'status': 'onFailure',
          'summary': 'Fallback file says failure.',
        }),
      );

      coordinator.submitMcpReport(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        payload: const <String, Object?>{
          'status': 'onSuccess',
          'summary': 'MCP says success.',
        },
      );

      final resolved = await contract.resolveOutcome(
        context: ctx,
        processResult: const ProcessExecutionResult(exitCode: 0),
      );
      expect(resolved.isSuccess, isTrue);
      expect(resolved.valueOrNull?.status, ResultContractStatus.success);
      expect(resolved.valueOrNull?.summary, 'MCP says success.');
    });

    test(
      'reads and validates result.json when exit code is 0 and no MCP report',
      () async {
        final ctx = makeContext();
        final session = (await contract.openSession(ctx)).valueOrNull!;
        addTearDown(session.dispose);

        await File(session.resultJsonPath).writeAsString(
          jsonEncode(const <String, Object?>{
            'status': 'onFailure',
            'summary': 'Tests failed.',
            'data': <String, Object?>{'failedCount': 3},
          }),
        );

        final resolved = await contract.resolveOutcome(
          context: ctx,
          processResult: const ProcessExecutionResult(exitCode: 0),
        );
        expect(resolved.isSuccess, isTrue);
        expect(resolved.valueOrNull?.status, ResultContractStatus.failure);
        expect(resolved.valueOrNull?.output, const <String, Object?>{
          'failedCount': 3,
        });
      },
    );

    test('fails on exit code 0 without report (ADR 0003)', () async {
      final ctx = makeContext();
      final session = (await contract.openSession(ctx)).valueOrNull!;
      addTearDown(session.dispose);

      final resolved = await contract.resolveOutcome(
        context: ctx,
        processResult: const ProcessExecutionResult(exitCode: 0),
      );
      expect(resolved.isFailure, isTrue);
      expect(resolved.failureOrNull, isA<NodeExecutionFailure>());
    });

    test(
      'non-zero exit code fails as infrastructure error even when result.json '
      'exists',
      () async {
        final ctx = makeContext();
        final session = (await contract.openSession(ctx)).valueOrNull!;
        addTearDown(session.dispose);

        await File(session.resultJsonPath).writeAsString(
          jsonEncode(const <String, Object?>{
            'status': 'onSuccess',
            'summary': 'Should be ignored because process crashed.',
          }),
        );

        final resolved = await contract.resolveOutcome(
          context: ctx,
          processResult: const ProcessExecutionResult(exitCode: 1),
        );
        expect(resolved.isFailure, isTrue);
        final failure = resolved.failureOrNull! as NodeExecutionFailure;
        expect(failure.exitCode, 1);
      },
    );

    test(
      'escapes ".." and path separators in fallback paths without collisions',
      () {
        final runsRoot = p.join(dataDir, 'runs');
        final dotDotPath = contract.fallbackResultJsonPath(
          runId: '..',
          nodeId: '../evil',
        );
        final slashPath = contract.fallbackResultJsonPath(
          runId: 'a/b',
          nodeId: 'c_d',
        );
        final underscorePath = contract.fallbackResultJsonPath(
          runId: 'a_b',
          nodeId: 'c_d',
        );

        expect(p.isWithin(runsRoot, dotDotPath), isTrue);
        expect(p.isWithin(runsRoot, slashPath), isTrue);
        expect(slashPath, isNot(equals(underscorePath)));
      },
    );

    test(
      'openSession deletes stale result.json before launching harness',
      () async {
        final ctx = makeContext();
        final stalePath = contract.fallbackResultJsonPath(
          runId: ctx.runId,
          nodeId: ctx.nodeId,
          attempt: ctx.attempt,
        );
        await File(stalePath).parent.create(recursive: true);
        await File(stalePath)
            .writeAsString('{"status":"onSuccess","summary":"stale"}');
        expect(File(stalePath).existsSync(), isTrue);

        final session = (await contract.openSession(ctx)).valueOrNull!;
        addTearDown(session.dispose);
        expect(File(stalePath).existsSync(), isFalse);
      },
    );

    test(
      'rejects re-registering an attempt that already has a locked report',
      () async {
        final ctx = makeContext();
        final session = (await contract.openSession(ctx)).valueOrNull!;
        addTearDown(session.dispose);

        final submit = coordinator.submitMcpReport(
          runId: ctx.runId,
          nodeId: ctx.nodeId,
          attempt: ctx.attempt,
          payload: const <String, Object?>{
            'status': 'onSuccess',
            'summary': 'Locked.',
          },
        );
        expect(submit.isSuccess, isTrue);

        final reOpen = await contract.openSession(ctx);
        expect(reOpen.failureOrNull, isA<ConflictFailure>());
      },
    );

    test(
      'openSession unregisters attempt if temp-file creation fails',
      () async {
        final blockingFile = File(p.join(dataDir, 'runs'));
        await blockingFile.writeAsString('not-a-directory');

        final ctx = makeContext();
        await expectLater(
          contract.openSession(ctx),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          coordinator.isAttemptRegistered(
            runId: ctx.runId,
            nodeId: ctx.nodeId,
            attempt: ctx.attempt,
          ),
          isFalse,
        );
      },
    );

    test(
      'session.dispose cancels pending ask_human pauses for that attempt',
      () async {
        final pauseGateway = InMemoryHumanPauseGateway();
        addTearDown(pauseGateway.dispose);
        final contractWithGateway = HiveResultContract(
          coordinator: coordinator,
          dataDir: dataDir,
          socketPath: p.join(dataDir, 'backend.sock'),
          mcpLocator: HiveMcpLocator(
            overrideCommand: const HiveMcpLaunchCommand(executable: 'hive-mcp'),
          ),
          humanPauseGateway: pauseGateway,
        );

        final ctx = makeContext();
        final session = (await contractWithGateway.openSession(ctx))
            .valueOrNull!;
        final pauseFuture = pauseGateway.requestHumanAnswer(
          runId: ctx.runId,
          nodeId: ctx.nodeId,
          attempt: ctx.attempt,
          question: 'Need input?',
        );

        await session.dispose();
        expect((await pauseFuture).failureOrNull, isA<ConflictFailure>());
      },
    );
  });
}
