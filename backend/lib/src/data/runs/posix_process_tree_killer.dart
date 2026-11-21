import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';

const int _sigTerm = 15;
const int _sigKill = 9;
const int _esrch = 3;

typedef _KillNative = Int32 Function(Int32 pid, Int32 sig);
typedef _KillDart = int Function(int pid, int sig);
typedef _GetPgidNative = Int32 Function(Int32 pid);
typedef _GetPgidDart = int Function(int pid);
typedef _SetPgidNative = Int32 Function(Int32 pid, Int32 pgid);
typedef _SetPgidDart = int Function(int pid, int pgid);
typedef _GetPidNative = Int32 Function();
typedef _GetPidDart = int Function();
typedef _ErrnoPtrNative = Pointer<Int32> Function();
typedef _ErrnoPtrDart = Pointer<Int32> Function();

final class _PosixLibc {
  new _() {
    final lib = DynamicLibrary.process();
    kill = lib.lookupFunction<_KillNative, _KillDart>('kill');
    getpgid = lib.lookupFunction<_GetPgidNative, _GetPgidDart>('getpgid');
    setpgid = lib.lookupFunction<_SetPgidNative, _SetPgidDart>('setpgid');
    getpid = lib.lookupFunction<_GetPidNative, _GetPidDart>('getpid');
    if (Platform.isMacOS) {
      _errnoLocation = lib.lookupFunction<_ErrnoPtrNative, _ErrnoPtrDart>(
        '__error',
      );
    } else {
      _errnoLocation = lib.lookupFunction<_ErrnoPtrNative, _ErrnoPtrDart>(
        '__errno_location',
      );
    }
  }

  static final _PosixLibc instance = ._();

  late final _KillDart kill;
  late final _GetPgidDart getpgid;
  late final _SetPgidDart setpgid;
  late final _GetPidDart getpid;
  late final _ErrnoPtrDart _errnoLocation;

  int get errno => _errnoLocation().value;
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
  final Set<int> knownPids = <int>{};
  bool exited = false;
  bool killing = false;
  bool cancelAttempted = false;
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
    this.skipTerminateForTesting = false,
  });

  /// Grace period between `SIGTERM` and `SIGKILL`.
  final Duration gracePeriod;

  /// Maximum time to wait after `SIGKILL` for the tree to exit.
  final Duration confirmationTimeout;

  /// Interval between exit-confirmation polls.
  final Duration pollInterval;

  /// Test-only hook that skips sending `SIGTERM`/`SIGKILL` so timeout and
  /// `cancellationUncertain` handling can be tested deterministically.
  final bool skipTerminateForTesting;

  final List<_TrackedPosixProcess> _tracked = <_TrackedPosixProcess>[];
  final Set<String> _cancellingRuns = <String>{};

  @override
  bool isRunCancelling(String runId) => _cancellingRuns.contains(runId);

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
      )..knownPids.add(pid),
    );
  }

  @override
  void untrack(Process process) {
    for (var i = _tracked.length - 1; i >= 0; i--) {
      final entry = _tracked[i];
      if (entry.process.pid != process.pid || entry.killing) continue;
      entry.exited = true;
      // Keep tracking the process group if surviving members remain or if a
      // previous cancel attempt was unconfirmed.
      if (!entry.cancelAttempted && _isConfirmedExited(entry)) {
        _tracked.removeAt(i);
      }
    }
  }

  @override
  Future<Result<void>> killTree({required String runId, String? nodeId}) async {
    if (nodeId == null) {
      _cancellingRuns.add(runId);
    }

    final targets = _tracked
        .where(
          (entry) =>
              entry.runId == runId &&
              (nodeId == null || entry.nodeId == nodeId),
        )
        .toList(growable: false);

    if (targets.isEmpty) {
      _cancellingRuns.remove(runId);
      return const Success(null);
    }

    for (final entry in targets) {
      entry
        ..killing = true
        ..cancelAttempted = true;
      if (!entry.hasOwnProcessGroup) {
        entry.knownPids.addAll(await _collectTreePids(entry.process.pid));
      }
      if (!skipTerminateForTesting) {
        if (entry.hasOwnProcessGroup) {
          _PosixLibc.instance.kill(-entry.pgid, _sigTerm);
        } else {
          for (final pid in entry.knownPids) {
            _PosixLibc.instance.kill(pid, _sigTerm);
          }
        }
      }
    }

    if (await _waitUntilConfirmed(targets, gracePeriod)) {
      _removeTargets(runId, targets);
      return const Success(null);
    }

    if (!skipTerminateForTesting) {
      for (final entry in targets) {
        if (entry.hasOwnProcessGroup) {
          _PosixLibc.instance.kill(-entry.pgid, _sigKill);
        } else {
          entry.knownPids.addAll(await _collectTreePids(entry.process.pid));
          for (final pid in entry.knownPids) {
            _PosixLibc.instance.kill(pid, _sigKill);
          }
        }
      }
    }

    if (await _waitUntilConfirmed(targets, confirmationTimeout)) {
      _removeTargets(runId, targets);
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

  void _removeTargets(String runId, List<_TrackedPosixProcess> targets) {
    targets.forEach(_tracked.remove);
    if (!_tracked.any((e) => e.runId == runId)) {
      _cancellingRuns.remove(runId);
    }
  }

  Future<bool> _waitUntilConfirmed(
    List<_TrackedPosixProcess> targets,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      var allConfirmed = true;
      for (final entry in targets) {
        if (!_isConfirmedExited(entry)) {
          allConfirmed = false;
          break;
        }
      }
      if (allConfirmed) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(pollInterval);
    }
  }

  bool _isConfirmedExited(_TrackedPosixProcess entry) {
    if (!entry.exited) return false;
    if (entry.hasOwnProcessGroup) {
      return _isTargetGone(-entry.pgid);
    }
    for (final pid in entry.knownPids) {
      if (!_isTargetGone(pid)) return false;
    }
    return true;
  }

  /// Returns `true` only when `kill(target, 0)` fails with `ESRCH` (`3`).
  /// `EPERM` (`1`) or `0` means at least one matching process still exists.
  bool _isTargetGone(int target) {
    final libc = _PosixLibc.instance;
    if (libc.kill(target, 0) == 0) return false;
    return libc.errno == _esrch;
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
