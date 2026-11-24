import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/nodes/fan_out_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

Workflow _sampleWorkflow({
  String id = 'child-wf',
  String name = 'Child Flow',
  bool hasFanOut = false,
}) => Workflow(
  id: id,
  name: name,
  nodes: [
    WorkflowNode(
      id: 'n1',
      type: hasFanOut ? NodeTypeId.fanOut : NodeTypeId.command,
      label: 'Step',
      position: const WorkflowPosition(x: 0, y: 0),
    ),
  ],
  edges: const [],
  entryNodeId: 'n1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Run _run(
  String id, {
  RunStatus status = RunStatus.succeeded,
  String? errorMessage,
}) => Run(
  id: id,
  workflowId: 'child-wf',
  workflowName: 'Child Flow',
  workflowDefinition: _sampleWorkflow(),
  workspacePath: '/ws',
  status: status,
  startedAt: DateTime.utc(2026),
  errorMessage: errorMessage,
);

NodeExecutionContext _context({
  Map<String, Object?>? config,
  Map<String, Object?>? inputs,
  String? workspaceId = 'ws-1',
  String? nodeLabel = 'Fan',
  String? runInput,
}) => NodeExecutionContext(
  runId: 'parent',
  nodeId: 'fan',
  nodeLabel: nodeLabel,
  workspacePath: '.',
  workspaceId: workspaceId,
  config:
      config ??
      const {
        'workflowId': 'child-wf',
        'itemsNodeId': 'planner',
        'itemsPath': 'issues',
      },
  inputs:
      inputs ??
      const {
        'nodeOutputs': {
          'planner': {
            'outputLabel': 'onSuccess',
            'data': {
              'issues': ['a', 'b'],
            },
          },
        },
      },
  runInput: runInput,
);

final class _FakeChildRunPort implements ChildRunPort {
  int pinCalls = 0;
  Result<Workflow> pinResult = Success(_sampleWorkflow());
  Result<ParentWorkspaceInfo> infoResult = const Success(
    ParentWorkspaceInfo(isGit: true, headCommit: 'abc123'),
  );
  final List<ChildRunRequest> started = [];
  final List<({String runId, String nodeId, String message})> warnings = [];
  Result<Run> Function(ChildRunRequest request)? startBehavior;
  final Map<String, List<Result<Run>>> getRunScripts = {};
  final Map<String, Result<Map<String, Object?>?>> finalOutputs = {};

  int inFlight = 0;
  int maxInFlight = 0;
  int _nextId = 1;

  @override
  Future<Result<Workflow>> pinWorkflow({
    required String workflowId,
    required String workspaceId,
  }) async {
    pinCalls++;
    return pinResult;
  }

  @override
  Future<Result<ParentWorkspaceInfo>> inspectParentWorkspace({
    required String runId,
  }) async => infoResult;

  @override
  Future<Result<Run>> startChildRun(ChildRunRequest request) async {
    started.add(request);
    if (startBehavior != null) {
      final res = startBehavior!(request);
      if (res is Success<Run>) {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
      }
      return res;
    }
    final id = 'child-${_nextId++}';
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    return Success(_run(id, status: RunStatus.running));
  }

  @override
  Future<Result<Run>> getRun(String runId) async {
    final script = getRunScripts[runId];
    final result = script == null || script.isEmpty
        ? Success(_run(runId, status: RunStatus.succeeded))
        : script.length == 1
        ? script.first
        : script.removeAt(0);
    if (result case Success(:final value)) {
      if (value.status == RunStatus.succeeded ||
          value.status == RunStatus.failed ||
          value.status == RunStatus.cancelled ||
          value.status == RunStatus.cancellationUncertain) {
        inFlight--;
      }
    } else {
      inFlight--;
    }
    return result;
  }

  @override
  Future<Result<Map<String, Object?>?>> finalOutputOf(String runId) async =>
      finalOutputs[runId] ?? const Success(null);

  @override
  Future<void> recordWarning({
    required String runId,
    required String nodeId,
    required String message,
  }) async {
    warnings.add((runId: runId, nodeId: nodeId, message: message));
  }
}

void main() {
  late _FakeChildRunPort port;
  late FanOutNode node;

  setUp(() {
    port = _FakeChildRunPort();
    node = FanOutNode(
      childRuns: port,
      pollInterval: const Duration(milliseconds: 1),
    );
  });

  test('fails on invalid config (blank workflowId)', () async {
    final res = await node.execute(
      _context(
        config: const {
          'workflowId': '  ',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
        },
      ),
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(port.pinCalls, 0);
  });

  test('fails when the items node has not produced an output', () async {
    final res = await node.execute(
      _context(inputs: const {'nodeOutputs': <String, Object?>{}}),
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(res.failureOrNull!.message, contains('planner'));
    expect(port.pinCalls, 0);
  });

  test('fails when the items path is missing', () async {
    final res = await node.execute(
      _context(
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {'other': []},
            },
          },
        },
      ),
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(res.failureOrNull!.message, contains('issues'));
  });

  test('fails when the value is not a list', () async {
    final res = await node.execute(
      _context(
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {'issues': 'not-a-list'},
            },
          },
        },
      ),
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(res.failureOrNull!.message, contains('not a list'));
  });

  test(
    'empty list ends with onSuccess, empty children, a warning, no pin, no child',
    () async {
      final res = await node.execute(
        _context(
          inputs: const {
            'nodeOutputs': {
              'planner': {
                'outputLabel': 'onSuccess',
                'data': {'issues': <Object?>[]},
              },
            },
          },
        ),
      );

      final outcome = res.valueOrNull!;
      expect(outcome.outputLabel, NodeOutput.onSuccess);
      expect(outcome.data, {
        'total': 0,
        'succeeded': 0,
        'failed': 0,
        'children': <Object?>[],
      });
      expect(port.pinCalls, 0);
      expect(port.started, isEmpty);
      expect(port.warnings, hasLength(1));
      expect(port.warnings.single.nodeId, 'fan');
      expect(port.warnings.single.message, isNotEmpty);
    },
  );

  test('more items than maxItems fails before pinning or starting', () async {
    final res = await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'maxItems': 2,
        },
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {
                'issues': [1, 2, 3],
              },
            },
          },
        },
      ),
    );

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(port.pinCalls, 0);
    expect(port.started, isEmpty);
  });

  test('unresolved workflow fails the node before any child starts', () async {
    port.pinResult = const FailureResult(NotFoundFailure('No such workflow'));

    final res = await node.execute(_context());

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(res.failureOrNull!.message, contains('No such workflow'));
    expect(port.started, isEmpty);
  });

  test('pinned workflow with a fan-out node fails the node', () async {
    port.pinResult = Success(_sampleWorkflow(hasFanOut: true));

    final res = await node.execute(_context());

    expect(res.failureOrNull, isA<ValidationFailure>());
    expect(res.failureOrNull!.message, contains('nested fan-out'));
    expect(port.started, isEmpty);
  });

  test('pins once and gives every child the same workflow', () async {
    final pinned = _sampleWorkflow();
    port.pinResult = Success(pinned);

    final res = await node.execute(_context());

    expect(res.isSuccess, isTrue);
    expect(port.pinCalls, 1);
    expect(port.started, hasLength(2));
    expect(identical(port.started[0].workflow, pinned), isTrue);
    expect(identical(port.started[1].workflow, pinned), isTrue);
  });

  test(
    'string item is the input as is; other items are formatted JSON',
    () async {
      final res = await node.execute(
        _context(
          runInput: 'parent-input-ignored',
          inputs: const {
            'nodeOutputs': {
              'planner': {
                'outputLabel': 'onSuccess',
                'data': {
                  'issues': [
                    'a',
                    {'k': 1},
                  ],
                },
              },
            },
          },
        ),
      );

      expect(res.isSuccess, isTrue);
      expect(port.started[0].input, 'a');
      expect(port.started[1].input, '{\n  "k": 1\n}');
    },
  );

  test('inputField selects part of the item and missing fails only that child', () async {
    final res = await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'inputField': 'prompt',
        },
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {
                'issues': [
                  {'prompt': 'ok'},
                  {'other': 1},
                ],
              },
            },
          },
        },
      ),
    );

    final outcome = res.valueOrNull!;
    expect(outcome.outputLabel, NodeOutput.onFailure);
    expect(port.started, hasLength(1));
    expect(port.started.single.input, 'ok');
    final children = outcome.data['children']! as List<Object?>;
    final second = children[1]! as Map<String, Object?>;
    expect(second['status'], 'failed');
    expect(second['runId'], isNull);
    expect(second['error'], contains('prompt'));
  });

  test('overridesField builds node overrides and rejects non-map', () async {
    final res = await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'overridesField': 'overrides',
        },
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {
                'issues': [
                  {
                    'overrides': {
                      'h': {'model': 'm1'},
                    },
                  },
                  {'overrides': 'bad'},
                  <String, Object?>{},
                ],
              },
            },
          },
        },
      ),
    );

    final outcome = res.valueOrNull!;
    expect(outcome.outputLabel, NodeOutput.onFailure);
    expect(port.started, hasLength(2));
    expect(
      port.started[0].nodeOverrides,
      const {'h': NodeOverride(model: 'm1')},
    );
    expect(port.started[1].nodeOverrides, isNull);
  });

  test(
    'child names: nameField, default <label>-<n>, sanitized unique worktree names',
    () async {
      final res = await node.execute(
        _context(
          config: const {
            'workflowId': 'child-wf',
            'itemsNodeId': 'planner',
            'itemsPath': 'issues',
            'nameField': 'title',
          },
          inputs: const {
            'nodeOutputs': {
              'planner': {
                'outputLabel': 'onSuccess',
                'data': {
                  'issues': [
                    {'title': 'Fix bug #1'},
                    {'title': 'Fix bug #1'},
                    <String, Object?>{},
                  ],
                },
              },
            },
          },
        ),
      );

      expect(res.isSuccess, isTrue);
      expect(port.started.map((r) => r.name), [
        'Fix bug #1',
        'Fix bug #1',
        'Fan-3',
      ]);
      expect(port.started.map((r) => r.worktreeName), [
        'Fix-bug-1',
        'Fix-bug-1-2',
        'Fan-3',
      ]);
    },
  );

  test('git workspace: worktree placement from the HEAD commit', () async {
    port.infoResult = const Success(
      ParentWorkspaceInfo(isGit: true, headCommit: 'abc'),
    );

    final res = await node.execute(_context());

    expect(res.isSuccess, isTrue);
    expect(port.warnings, isEmpty);
    for (final req in port.started) {
      expect(req.placement, ChildRunPlacement.worktree);
      expect(req.baseCommit, 'abc');
    }
  });

  test('dirty git folder records a warning', () async {
    port.infoResult = const Success(
      ParentWorkspaceInfo(
        isGit: true,
        headCommit: 'abc',
        hasUncommittedChanges: true,
      ),
    );

    final res = await node.execute(_context());

    expect(res.isSuccess, isTrue);
    expect(port.warnings, hasLength(1));
  });

  test('non-git workspace: lent folder placement and one child at a time', () async {
    port.infoResult = const Success(ParentWorkspaceInfo(isGit: false));

    final res = await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'concurrency': 3,
        },
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {
                'issues': ['a', 'b', 'c'],
              },
            },
          },
        },
      ),
    );

    expect(res.isSuccess, isTrue);
    expect(port.maxInFlight, 1);
    for (final req in port.started) {
      expect(req.placement, ChildRunPlacement.lentFolder);
      expect(req.worktreeName, isNull);
    }
  });

  test('respects concurrency', () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1', status: RunStatus.succeeded)),
    ];
    port.getRunScripts['child-2'] = [
      Success(_run('child-2', status: RunStatus.running)),
      Success(_run('child-2', status: RunStatus.succeeded)),
    ];

    final res = await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'concurrency': 2,
        },
        inputs: const {
          'nodeOutputs': {
            'planner': {
              'outputLabel': 'onSuccess',
              'data': {
                'issues': ['a', 'b', 'c', 'd', 'e'],
              },
            },
          },
        },
      ),
    );

    expect(res.isSuccess, isTrue);
    expect(port.maxInFlight, 2);
    expect(port.started, hasLength(5));
  });

  test(
    'all children succeed: onSuccess with each child status, run id and final output',
    () async {
      port.finalOutputs['child-1'] = const Success({
        'outputLabel': 'onSuccess',
        'data': {'x': 1},
      });
      port.finalOutputs['child-2'] = const Success({
        'outputLabel': 'onSuccess',
        'data': {'x': 2},
      });

      final res = await node.execute(_context());
      final outcome = res.valueOrNull!;

      expect(outcome.outputLabel, NodeOutput.onSuccess);
      expect(outcome.data['total'], 2);
      expect(outcome.data['succeeded'], 2);
      expect(outcome.data['failed'], 0);
      final children = outcome.data['children']! as List<Object?>;
      expect(children[0], {
        'index': 0,
        'name': 'Fan-1',
        'status': 'succeeded',
        'runId': 'child-1',
        'output': {
          'outputLabel': 'onSuccess',
          'data': {'x': 1},
        },
        'error': null,
      });
    },
  );

  test(
    'a failing child does not stop the others and the node ends with onFailure',
    () async {
      port.getRunScripts['child-1'] = [
        Success(
          _run('child-1', status: RunStatus.failed, errorMessage: 'boom'),
        ),
      ];

      final res = await node.execute(_context());
      final outcome = res.valueOrNull!;

      expect(outcome.outputLabel, NodeOutput.onFailure);
      expect(outcome.data['succeeded'], 1);
      expect(outcome.data['failed'], 1);
      expect(port.started, hasLength(2));
    },
  );

  test('a child that cannot start is a failed entry without a run id', () async {
    var count = 0;
    port.startBehavior = (req) {
      count++;
      if (count == 1) {
        return const FailureResult(
          ValidationFailure('Invalid node overrides: x'),
        );
      }
      return Success(_run('child-$count', status: RunStatus.running));
    };

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;

    expect(outcome.outputLabel, NodeOutput.onFailure);
    final children = outcome.data['children']! as List<Object?>;
    final first = children[0]! as Map<String, Object?>;
    expect(first['status'], 'failed');
    expect(first['runId'], isNull);
    expect(first['error'], contains('Invalid node overrides: x'));
    expect((children[1]! as Map<String, Object?>)['status'], 'succeeded');
  });

  test('waits through paused and interrupted until a final status', () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1', status: RunStatus.paused)),
      Success(_run('child-1', status: RunStatus.interrupted)),
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1', status: RunStatus.succeeded)),
    ];

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;

    expect(outcome.outputLabel, NodeOutput.onSuccess);
    expect(port.getRunScripts['child-1'], hasLength(1));
  });

  test('cancellationUncertain counts as a final failed child', () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.cancellationUncertain)),
    ];

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;

    expect(outcome.outputLabel, NodeOutput.onFailure);
    final children = outcome.data['children']! as List<Object?>;
    expect(
      (children[0]! as Map<String, Object?>)['status'],
      'cancellationUncertain',
    );
  });

  test('a child deleted while waiting is a failed entry', () async {
    port.getRunScripts['child-1'] = [
      const FailureResult(NotFoundFailure('gone')),
    ];

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;

    expect(outcome.outputLabel, NodeOutput.onFailure);
    final children = outcome.data['children']! as List<Object?>;
    final first = children[0]! as Map<String, Object?>;
    expect(first['status'], 'failed');
    expect(first['error'], 'Child run was deleted.');
  });

  test('an exception inside a child task becomes a failed entry', () async {
    port.startBehavior = (_) => throw StateError('unexpected');

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;

    expect(outcome.outputLabel, NodeOutput.onFailure);
    final children = outcome.data['children']! as List<Object?>;
    expect((children[0]! as Map<String, Object?>)['status'], 'failed');
    expect(
      (children[0]! as Map<String, Object?>)['error'],
      contains('unexpected'),
    );
  });
}
