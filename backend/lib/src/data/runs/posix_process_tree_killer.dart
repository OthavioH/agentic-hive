import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';

const int _sigTerm = 15;
const int _sigKill = 9;

typedef _KillNative = Int32 Function(Int32 pid, Int32 sig);
typedef _KillDart = int Function(int pid, int sig);
typedef _GetPgidNative = Int32 Function(Int32 pid);
typedef _GetPgidDart = int Function(int pid);
typedef _SetPgidNative = Int32 Function(Int32 pid, Int32 pgid);
typedef _SetPgidDart = int Function(int pid, int pgid);
typedef _GetPidNative = Int32 Function();
typedef _GetPidDart = int Function();

final class _PosixLibc {
  new _() {
    final lib = DynamicLibrary.process();
    kill = lib.lookupFunction<_KillNative, _KillDart>('kill');
    getpgid = lib.lookupFunction<_GetPgidNative, _GetPgidDart>('getpgid');
    setpgid = lib.lookupFunction<_SetPgidNative, _SetPgidDart>('setpgid');
    getpid = lib.lookupFunction<_GetPidNative, _GetPidDart>('getpid');
  }

  static final _PosixLibc instance = ._();

  late final _KillDart kill;
  late final _GetPgidDart getpgid;
  late final _SetPgidDart setpgid;
  late final _GetPidDart getpid;
}

final class _TrackedPosixProcess {
  new({
    required this.runId,
    required this.nodeId,
    required this.process,
    required this.pgid,
    required this.hasOwnProcessGroup,
  }) {
    unawaited(
      process.exitCode.then((_) {
        exited = true;
      }),
    );
  }

  final String runId;
  final String nodeId;
  final Process process;
  final int pgid;
  final bool hasOwnProcessGroup;
  bool exited = false;
  bool killing = false;
}

/// POSIX (Linux and macOS) [ProcessTreeKiller] and [ProcessTreeTracker]
/// using process groups (`SIGTERM` → 3s grace → `SIGKILL` → exit confirmation)
/// per ADR 0012.
final class PosixProcessTreeKiller
    implements ProcessTreeKiller, ProcessTreeTracker {
  /// Creates a POSIX process-tree killer.
  new({
    this.gracePeriod = const Duration(seconds: 3),
    this.confirmationTimeout = const Duration(seconds: 5),
    this.pollInterval = const Duration(milliseconds: 25),
  });

  /// Grace period between `SIGTERM` and `SIGKILL`.
  final Duration gracePeriod;

  /// Maximum time to wait after `SIGKILL` for the tree to exit.
  final Duration confirmationTimeout;

  /// Interval between exit-confirmation polls.
  final Duration pollInterval;

  final List<_TrackedPosixProcess> _tracked = <_TrackedPosixProcess>[];

  @override
  void track({
    required String runId,
    required String nodeId,
    required Process process,
  }) {
    final libc = _PosixLibc.instance;
    final pid = process.pid;
    final backendPgid = libc.getpgid(libc.getpid());
    var pgid = libc.getpgid(pid);
    if (pgid == backendPgid) {
      if (libc.setpgid(pid, pid) == 0) {
        pgid = pid;
      } else {
        pgid = libc.getpgid(pid);
      }
    }
    final hasOwnGroup = pgid > 0 && pgid != backendPgid;

    _tracked.add(
      _TrackedPosixProcess(
        runId: runId,
        nodeId: nodeId,
        process: process,
        pgid: pgid,
        hasOwnProcessGroup: hasOwnGroup,
      ),
    );
  }

  @override
  void untrack(Process process) {
    for (var i = _tracked.length - 1; i >= 0; i--) {
      final entry = _tracked[i];
      if (entry.process.pid == process.pid && !entry.killing) {
        _tracked.removeAt(i);
      }
    }
  }

  @override
  Future<Result<void>> killTree({required String runId, String? nodeId}) async {
    final targets = _tracked
        .where(
          (entry) =>
              entry.runId == runId &&
              (nodeId == null || entry.nodeId == nodeId),
        )
        .toList(growable: false);

    if (targets.isEmpty) return const Success(null);

    final fallbackPids = <int, Set<int>>{};
    for (final entry in targets) {
      entry.killing = true;
      if (entry.hasOwnProcessGroup) {
        _PosixLibc.instance.kill(-entry.pgid, _sigTerm);
      } else {
        final tree = await _collectTreePids(entry.process.pid);
        fallbackPids[entry.process.pid] = tree;
        for (final pid in tree) {
          _PosixLibc.instance.kill(pid, _sigTerm);
        }
      }
    }

    if (await _waitUntilConfirmed(targets, fallbackPids, gracePeriod)) {
      _removeTargets(targets);
      return const Success(null);
    }

    for (final entry in targets) {
      if (entry.hasOwnProcessGroup) {
        _PosixLibc.instance.kill(-entry.pgid, _sigKill);
      } else {
        final tree = <int>{
          ...?fallbackPids[entry.process.pid],
          ...await _collectTreePids(entry.process.pid),
        };
        fallbackPids[entry.process.pid] = tree;
        for (final pid in tree) {
          _PosixLibc.instance.kill(pid, _sigKill);
        }
      }
    }

    if (await _waitUntilConfirmed(targets, fallbackPids, confirmationTimeout)) {
      _removeTargets(targets);
      return const Success(null);
    }

    for (final entry in targets) {
      entry.killing = false;
    }
    return FailureResult(
      NodeExecutionFailure(
        'Timed out after ${confirmationTimeout.inSeconds}s waiting for '
        'process tree of run "$runId" to exit.',
      ),
    );
  }

  void _removeTargets(List<_TrackedPosixProcess> targets) {
    targets.forEach(_tracked.remove);
  }

  Future<bool> _waitUntilConfirmed(
    List<_TrackedPosixProcess> targets,
    Map<int, Set<int>> fallbackPids,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      var allConfirmed = true;
      for (final entry in targets) {
        if (!_isConfirmedExited(entry, fallbackPids[entry.process.pid])) {
          allConfirmed = false;
          break;
        }
      }
      if (allConfirmed) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(pollInterval);
    }
  }

  bool _isConfirmedExited(_TrackedPosixProcess entry, Set<int>? pids) {
    if (!entry.exited) return false;
    final libc = _PosixLibc.instance;
    if (entry.hasOwnProcessGroup) {
      return libc.kill(-entry.pgid, 0) != 0;
    }
    if (pids == null) return libc.kill(entry.process.pid, 0) != 0;
    for (final pid in pids) {
      if (libc.kill(pid, 0) == 0) return false;
    }
    return true;
  }

  Future<Set<int>> _collectTreePids(int rootPid) async {
    final result = <int>{rootPid};
    try {
      final ps = await Process.run('ps', const ['-eo', 'pid=,ppid=']);
      if (ps.exitCode != 0) return result;
      final childrenByParent = <int, List<int>>{};
      for (final line in (ps.stdout as String).split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) continue;
        final pid = int.tryParse(parts[0]);
        final ppid = int.tryParse(parts[1]);
        if (pid != null && ppid != null) {
          (childrenByParent[ppid] ??= <int>[]).add(pid);
        }
      }
      final queue = <int>[rootPid];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final children = childrenByParent[current];
        if (children == null) continue;
        for (final child in children) {
          if (result.add(child)) queue.add(child);
        }
      }
    } on ProcessException {
      // Fall back to rootPid only.
    }
    return result;
  }
}
