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

  Result<List<Run>> previousRuns = const Success(<Run>[]);
  final List<({String parentRunId, String parentNodeId})> listCalls = [];
  final List<String> resumed = [];
  final List<String> cancelled = [];
  Result<Run> Function(String runId)? resumeBehavior;
  RunStatus parentStatus = RunStatus.running;
  bool parentStopping = false;

  @override
  bool isStopping(String parentRunId) => parentStopping;

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
    if (runId == 'parent') {
      return Success(_run('parent', status: parentStatus));
    }
    final script = getRunScripts[runId];
    final result = script == null || script.isEmpty
        ? Success(_run(runId))
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

  @override
  Future<Result<List<Run>>> listChildRuns({
    required String parentRunId,
    required String parentNodeId,
  }) async {
    listCalls.add((parentRunId: parentRunId, parentNodeId: parentNodeId));
    return previousRuns;
  }

  @override
  Future<Result<Run>> resumeChildRun(String runId) async {
    resumed.add(runId);
    if (resumeBehavior != null) return resumeBehavior!(runId);
    return Success(_run(runId, status: RunStatus.running));
  }

  @override
  Future<Result<Run>> cancelChildRun(String runId) async {
    cancelled.add(runId);
    return Success(_run(runId, status: RunStatus.cancelled));
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
              'data': {'other': <Object?>[]},
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
    'empty list ends with onSuccess, empty children, warning, no pin/child',
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

  test(
    'inputField selects part of the item and missing fails only that child',
    () async {
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
    },
  );

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
    expect(port.started[0].nodeOverrides, const {
      'h': NodeOverride(model: 'm1'),
    });
    expect(port.started[1].nodeOverrides, isNull);
  });

  test('child names: nameField, default, unique worktree names', () async {
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
  });

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

  test(
    'non-git workspace: lent folder placement and one child at a time',
    () async {
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
    },
  );

  test('respects concurrency', () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1')),
    ];
    port.getRunScripts['child-2'] = [
      Success(_run('child-2', status: RunStatus.running)),
      Success(_run('child-2')),
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

  test('all children succeed: onSuccess with status, id and output', () async {
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
  });

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

  test(
    'a child that cannot start is a failed entry without a run id',
    () async {
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
    },
  );

  test('waits through paused and interrupted until a final status', () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1', status: RunStatus.paused)),
      Success(_run('child-1', status: RunStatus.interrupted)),
      Success(_run('child-1', status: RunStatus.running)),
      Success(_run('child-1')),
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

  Run childRun(String id, int index, RunStatus status, {String? name}) =>
      _run(id, status: status).copyWith(
        parentRunId: 'parent',
        parentNodeId: 'fan',
        childIndex: index,
        childName: name ?? 'Fan-${index + 1}',
        startedAt: DateTime.utc(2026, 1, index + 1),
      );

  test(
    'reuses a succeeded previous child and starts only the failed item',
    () async {
      port.previousRuns = Success([
        childRun('c-old-0', 0, RunStatus.succeeded),
        childRun('c-old-1', 1, RunStatus.failed),
      ]);
      port.finalOutputs['c-old-0'] = const Success({'ok': true});

      final res = await node.execute(_context());
      final outcome = res.valueOrNull!;

      expect(port.pinCalls, 1);
      expect(port.started, hasLength(1));
      expect(port.started.single.index, 1);

      final children = (outcome.data['children']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(children[0]['runId'], 'c-old-0');
      expect(children[0]['status'], 'succeeded');
      expect(children[0]['output'], {'ok': true});
      expect(children[1]['runId'], 'child-1');
    },
  );

  test('retry uses the latest child of an item', () async {
    port.previousRuns = Success([
      childRun(
        'c-fail',
        0,
        RunStatus.failed,
      ).copyWith(startedAt: DateTime.utc(2026)),
      childRun(
        'c-ok',
        0,
        RunStatus.succeeded,
      ).copyWith(startedAt: DateTime.utc(2026, 1, 2)),
    ]);

    await node.execute(_context());
    expect(port.started.map((r) => r.index), [1]);
  });

  test('matches by name when nameField is set', () async {
    port.previousRuns = Success([
      childRun('c-x', 5, RunStatus.succeeded, name: 'x'),
    ]);

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
                  {'title': 'x'},
                  {'title': 'y'},
                ],
              },
            },
          },
        },
      ),
    );
    expect(port.started, hasLength(1));
    expect(port.started.single.name, 'y');

    final children = (res.valueOrNull!.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['runId'], 'c-x');
  });

  test(
    'falls back to index when nameField is set but an item has no name',
    () async {
      port.previousRuns = Success([childRun('c-0', 0, RunStatus.succeeded)]);

      await node.execute(
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
                    <String, Object?>{},
                    {'title': 'y'},
                  ],
                },
              },
            },
          },
        ),
      );
      expect(port.started.map((r) => r.index), [1]);
    },
  );

  test(
    'cancelled and cancellationUncertain previous children are retried',
    () async {
      port.previousRuns = Success([
        childRun('c-0', 0, RunStatus.cancelled),
        childRun('c-1', 1, RunStatus.cancellationUncertain),
      ]);

      await node.execute(_context());
      expect(port.started, hasLength(2));
    },
  );

  test('retried worktree gets an -r<n> suffix', () async {
    port.previousRuns = Success([childRun('c0', 0, RunStatus.failed)]);

    await node.execute(_context());
    expect(port.started[0].worktreeName, 'Fan-1-r1');
    expect(port.started[1].worktreeName, 'Fan-2');
  });

  test(
    'waits for a running previous child instead of starting a new one',
    () async {
      port.previousRuns = Success([
        childRun('c-run', 0, RunStatus.running),
        childRun('c-ok', 1, RunStatus.succeeded),
      ]);
      port.getRunScripts['c-run'] = [
        Success(_run('c-run', status: RunStatus.running)),
        Success(_run('c-run')),
      ];

      final res = await node.execute(_context());
      expect(port.started, isEmpty);
      expect(port.resumed, isEmpty);
      final children = (res.valueOrNull!.data['children']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(children[0]['status'], 'succeeded');
    },
  );

  test('resumes an interrupted previous child and waits', () async {
    port.previousRuns = Success([
      childRun('c-int', 0, RunStatus.interrupted),
      childRun('c-ok', 1, RunStatus.succeeded),
    ]);
    port.getRunScripts['c-int'] = [Success(_run('c-int'))];

    final res = await node.execute(_context());
    expect(port.resumed, ['c-int']);
    expect(port.started, isEmpty);
    final children = (res.valueOrNull!.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['status'], 'succeeded');
  });

  test('a conflict while resuming is not an error', () async {
    port
      ..previousRuns = Success([
        childRun('c-int', 0, RunStatus.interrupted),
        childRun('c-ok', 1, RunStatus.succeeded),
      ])
      ..resumeBehavior = ((_) =>
          const FailureResult(ConflictFailure('already')))
      ..getRunScripts['c-int'] = [Success(_run('c-int'))];

    final res = await node.execute(_context());
    final children = (res.valueOrNull!.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['status'], 'succeeded');
  });

  test('a resume ConflictFailure while child stays interrupted fails that item '
      'with a warning instead of polling forever', () async {
    port
      ..previousRuns = Success([
        childRun('c-int', 0, RunStatus.interrupted),
        childRun('c-ok', 1, RunStatus.succeeded),
      ])
      ..resumeBehavior = ((_) => const FailureResult(
        ConflictFailure('Another run is active in the worktree.'),
      ))
      ..getRunScripts['c-int'] = [
        Success(childRun('c-int', 0, RunStatus.interrupted)),
      ];

    final res = await node
        .execute(_context())
        .timeout(const Duration(seconds: 2));
    final children = (res.valueOrNull!.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['status'], 'failed');
    expect(children[0]['runId'], 'c-int');
    expect(children[0]['error'], 'Another run is active in the worktree.');
    expect(children[1]['status'], 'succeeded');
    expect(port.warnings, hasLength(1));
  });

  test('a resume failure fails only that item', () async {
    port
      ..previousRuns = Success([
        childRun('c-int', 0, RunStatus.interrupted),
        childRun('c-ok', 1, RunStatus.succeeded),
      ])
      ..resumeBehavior = (_) => const FailureResult(UnexpectedFailure('boom'));

    final res = await node.execute(_context());
    final children = (res.valueOrNull!.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['status'], 'failed');
    expect(children[0]['error'], 'boom');
    expect(children[1]['status'], 'succeeded');
  });

  test('stops starting children once the parent is cancelling', () async {
    port.parentStatus = RunStatus.cancelling;

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;
    expect(port.started, isEmpty);
    expect(outcome.outputLabel, NodeOutput.onFailure);
    final children = (outcome.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final c in children) {
      expect(c['status'], 'cancelled');
      expect(c['runId'], isNull);
      expect(c['error'], 'The parent run stopped before this item started.');
    }
  });

  test('cancels a child that started after the parent stopped', () async {
    port.startBehavior = (req) {
      port.parentStatus = RunStatus.cancelling;
      return Success(_run('child-race', status: RunStatus.running));
    };

    await node.execute(
      _context(
        config: const {
          'workflowId': 'child-wf',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
          'concurrency': 1,
        },
      ),
    );
    expect(port.cancelled, ['child-race']);
  });

  test('a paused parent keeps starting children', () async {
    port.parentStatus = RunStatus.paused;

    final res = await node.execute(_context());
    expect(port.started, hasLength(2));
    expect(res.valueOrNull!.outputLabel, NodeOutput.onSuccess);
  });

  test("a cancelled child counts as that child's failure", () async {
    port.getRunScripts['child-1'] = [
      Success(_run('child-1', status: RunStatus.cancelled)),
    ];

    final res = await node.execute(_context());
    final outcome = res.valueOrNull!;
    expect(outcome.outputLabel, NodeOutput.onFailure);
    expect(outcome.data['failed'], 1);
    final children = (outcome.data['children']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(children[0]['status'], 'cancelled');
  });

  test('a previous-children lookup failure fails the node', () async {
    port.previousRuns = const FailureResult(PersistenceFailure('db'));

    final res = await node.execute(_context());
    expect(res.isFailure, isTrue);
  });
}
