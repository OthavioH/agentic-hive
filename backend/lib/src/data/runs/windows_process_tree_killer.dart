import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:win32/win32.dart';

const int _jobObjectLimitKillOnJobClose = 0x00002000;
const int _processTerminate = 0x0001;
const int _processSetQuota = 0x0100;
const int _processQueryLimitedInformation = 0x1000;
const int _synchronize = 0x00100000;
const int _th32csSnapProcess = 0x00000002;
const int _invalidHandleValue = -1;

final class _JobObjectBasicAccountingInformation extends Struct {
  @Int64()
  external int totalUserTime;

  @Int64()
  external int totalKernelTime;

  @Int64()
  external int thisPeriodTotalUserTime;

  @Int64()
  external int thisPeriodTotalKernelTime;

  @Uint32()
  external int totalPageFaultCount;

  @Uint32()
  external int totalProcesses;

  @Uint32()
  external int activeProcesses;

  @Uint32()
  external int totalTerminatedProcesses;
}

final class _JobObjectBasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;

  @Int64()
  external int perJobUserTimeLimit;

  @Uint32()
  external int limitFlags;

  @UintPtr()
  external int minimumWorkingSetSize;

  @UintPtr()
  external int maximumWorkingSetSize;

  @Uint32()
  external int activeProcessLimit;

  @UintPtr()
  external int affinity;

  @Uint32()
  external int priorityClass;

  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;

  @Uint64()
  external int writeOperationCount;

  @Uint64()
  external int otherOperationCount;

  @Uint64()
  external int readTransferCount;

  @Uint64()
  external int writeTransferCount;

  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;

  @UintPtr()
  external int processMemoryLimit;

  @UintPtr()
  external int jobMemoryLimit;

  @UintPtr()
  external int peakProcessMemoryUsed;

  @UintPtr()
  external int peakJobMemoryUsed;
}

final class _ProcessEntry32W extends Struct {
  @Uint32()
  external int dwSize;

  @Uint32()
  external int cntUsage;

  @Uint32()
  external int th32ProcessID;

  @UintPtr()
  external int th32DefaultHeapID;

  @Uint32()
  external int th32ModuleID;

  @Uint32()
  external int cntThreads;

  @Uint32()
  external int th32ParentProcessID;

  @Int32()
  external int pcPriClassBase;

  @Uint32()
  external int dwFlags;

  @Array(260)
  external Array<Uint16> szExeFile;
}

typedef _CreateToolhelp32SnapshotNative = Pointer<NativeType> Function(
  Uint32 dwFlags,
  Uint32 th32ProcessID,
);
typedef _CreateToolhelp32SnapshotDart = Pointer<NativeType> Function(
  int dwFlags,
  int th32ProcessID,
);
typedef _Process32IterNative = Int32 Function(
  Pointer<NativeType> hSnapshot,
  Pointer<_ProcessEntry32W> lppe,
);
typedef _Process32IterDart = int Function(
  Pointer<NativeType> hSnapshot,
  Pointer<_ProcessEntry32W> lppe,
);

final class _Toolhelp32 {
  new _() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    createSnapshot = kernel32
        .lookupFunction<
          _CreateToolhelp32SnapshotNative,
          _CreateToolhelp32SnapshotDart
        >('CreateToolhelp32Snapshot');
    first = kernel32.lookupFunction<_Process32IterNative, _Process32IterDart>(
      'Process32FirstW',
    );
    next = kernel32.lookupFunction<_Process32IterNative, _Process32IterDart>(
      'Process32NextW',
    );
  }

  static final _Toolhelp32 instance = ._();

  late final _CreateToolhelp32SnapshotDart createSnapshot;
  late final _Process32IterDart first;
  late final _Process32IterDart next;
}

final class _TrackedWindowsProcess {
  new({
    required this.runId,
    required this.nodeId,
    required this.process,
    required this.jobHandle,
    required this.processHandle,
    required this.knownDescendantPids,
    required this.descendantSnapshotValid,
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
  HANDLE? jobHandle;
  HANDLE? processHandle;
  final Set<int> knownDescendantPids;
  bool descendantSnapshotValid;
  bool exited = false;
  bool killing = false;
  bool cancelAttempted = false;

  void closeHandles() {
    final job = jobHandle;
    if (job != null) {
      CloseHandle(job);
      jobHandle = null;
    }
    final proc = processHandle;
    if (proc != null) {
      CloseHandle(proc);
      processHandle = null;
    }
  }
}

/// Windows [ProcessTreeKiller] and [ProcessTreeTracker] backed by Win32 Job
/// Objects (`dart:ffi` + `package:win32`), Toolhelp32 descendant snapshots,
/// and `taskkill /T /F` (ADR 0009, ADR 0012).
final class WindowsProcessTreeKiller
    implements ProcessTreeKiller, ProcessTreeTracker {
  /// Creates a Windows process-tree killer.
  new({
    this.confirmationTimeout = const Duration(seconds: 5),
    this.pollInterval = const Duration(milliseconds: 25),
    this.skipTerminateForTesting = false,
  });

  static final _log = Logger('process_tree_killer.windows');

  /// Maximum time to wait for confirmation that every process in the Job
  /// Object, the root handle, and any pre-assignment descendants have exited.
  final Duration confirmationTimeout;

  /// Interval between exit-confirmation polls.
  final Duration pollInterval;

  /// Test-only hook that skips sending the OS termination signal so timeout and
  /// `cancellationUncertain` handling can be tested deterministically.
  final bool skipTerminateForTesting;

  final List<_TrackedWindowsProcess> _tracked = <_TrackedWindowsProcess>[];
  final Set<String> _cancellingRuns = <String>{};

  @override
  bool isRunCancelling(String runId) => _cancellingRuns.contains(runId);

  @override
  void track({
    required String runId,
    required String nodeId,
    required Process process,
  }) {
    final pid = process.pid;
    HANDLE? jobHandle;
    HANDLE? processHandle;

    final procResult = OpenProcess(
      const PROCESS_ACCESS_RIGHTS(
        _processTerminate |
            _processSetQuota |
            _processQueryLimitedInformation |
            _synchronize,
      ),
      false,
      pid,
    );
    if (procResult.value.address != 0) {
      processHandle = procResult.value;
    }

    final jobResult = CreateJobObject(nullptr, null);
    if (jobResult.value.address != 0) {
      final job = jobResult.value;
      final limitInfo = calloc<_JobObjectExtendedLimitInformation>();
      try {
        limitInfo.ref.basicLimitInformation.limitFlags =
            _jobObjectLimitKillOnJobClose;
        final setOk = SetInformationJobObject(
          job,
          JobObjectExtendedLimitInformation,
          limitInfo,
          sizeOf<_JobObjectExtendedLimitInformation>(),
        );
        if (!setOk.value) {
          _log.warning(
            LogEvent(
              'process_tree.job_limit_failed',
              fields: {'runId': runId, 'pid': pid, 'error': setOk.error},
            ),
          );
        }
      } finally {
        calloc.free(limitInfo);
      }

      if (processHandle != null) {
        final assignOk = AssignProcessToJobObject(job, processHandle);
        if (assignOk.value) {
          jobHandle = job;
        } else {
          _log.warning(
            LogEvent(
              'process_tree.job_assign_failed',
              fields: {'runId': runId, 'pid': pid, 'error': assignOk.error},
            ),
          );
          CloseHandle(job);
        }
      } else {
        CloseHandle(job);
      }
    }

    // Snapshot any child processes spawned before AssignProcessToJobObject
    // completed and assign them to the Job Object as well.
    final initialDescendants = _snapshotDescendantPids(pid);
    final descendants = <int>{...?initialDescendants};
    if (jobHandle != null && descendants.isNotEmpty) {
      for (final childPid in descendants) {
        _tryAssignPidToJob(jobHandle, childPid);
      }
    }

    _tracked.add(
      _TrackedWindowsProcess(
        runId: runId,
        nodeId: nodeId,
        process: process,
        jobHandle: jobHandle,
        processHandle: processHandle,
        knownDescendantPids: descendants,
        descendantSnapshotValid: initialDescendants != null,
      ),
    );
  }

  void _tryAssignPidToJob(HANDLE job, int pid) {
    final childHandle = OpenProcess(
      const PROCESS_ACCESS_RIGHTS(_processTerminate | _processSetQuota),
      false,
      pid,
    );
    if (childHandle.value.address == 0) return;
    try {
      AssignProcessToJobObject(job, childHandle.value);
    } finally {
      CloseHandle(childHandle.value);
    }
  }

  @override
  void untrack(Process process) {
    for (var i = _tracked.length - 1; i >= 0; i--) {
      final entry = _tracked[i];
      if (entry.process.pid != process.pid || entry.killing) continue;
      // Do not forget the entry if cancellation was attempted and unconfirmed,
      // or if descendant processes are still alive in the job or tree.
      if (!entry.cancelAttempted && _isConfirmedExited(entry)) {
        entry.closeHandles();
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
      if (!skipTerminateForTesting) {
        await _terminateEntry(entry);
      }
    }

    final deadline = DateTime.now().add(confirmationTimeout);
    while (true) {
      var allConfirmed = true;
      for (final entry in targets) {
        if (!_isConfirmedExited(entry)) {
          allConfirmed = false;
          break;
        }
      }
      if (allConfirmed) {
        for (final entry in targets) {
          entry.closeHandles();
          _tracked.remove(entry);
        }
        if (!_tracked.any((e) => e.runId == runId)) {
          _cancellingRuns.remove(runId);
        }
        return const Success(null);
      }
      if (!DateTime.now().isBefore(deadline)) {
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
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _terminateEntry(_TrackedWindowsProcess entry) async {
    // Capture any descendants visible right now before terminating the root.
    final liveDescendants = _snapshotDescendantPids(entry.process.pid);
    if (liveDescendants != null) {
      entry.knownDescendantPids.addAll(liveDescendants);
      entry.descendantSnapshotValid = true;
    }

    // Run taskkill /T /F on the root while it is still alive so children that
    // escaped before AssignProcessToJobObject are terminated via the parent-PID
    // tree as well.
    try {
      await Process.run('taskkill', <String>[
        '/T',
        '/F',
        '/PID',
        '${entry.process.pid}',
      ]);
    } on ProcessException {
      entry.process.kill(ProcessSignal.sigkill);
    }

    final job = entry.jobHandle;
    if (job != null) {
      final terminated = TerminateJobObject(job, 1);
      if (!terminated.value) {
        _log.warning(
          LogEvent(
            'process_tree.terminate_job_failed',
            fields: {
              'runId': entry.runId,
              'pid': entry.process.pid,
              'error': terminated.error,
            },
          ),
        );
      }
    }

    // Also terminate any known descendant PIDs that survived root exit.
    for (final childPid in entry.knownDescendantPids) {
      if (_isPidAlive(childPid)) {
        try {
          await Process.run('taskkill', <String>[
            '/T',
            '/F',
            '/PID',
            '$childPid',
          ]);
        } on ProcessException {
          // Best-effort; confirmation loop checks _isPidAlive.
        }
      }
    }
  }

  bool _isConfirmedExited(_TrackedWindowsProcess entry) {
    final procHandle = entry.processHandle;
    final rootExited =
        entry.exited ||
        (procHandle != null &&
            WaitForSingleObject(procHandle, 0).value == WAIT_OBJECT_0);
    if (!rootExited) return false;

    final currentDescendants = _snapshotDescendantPids(entry.process.pid);
    if (currentDescendants != null) {
      entry.knownDescendantPids.addAll(currentDescendants);
      entry.descendantSnapshotValid = true;
    }

    for (final pid in entry.knownDescendantPids) {
      if (_isPidAlive(pid)) return false;
    }

    final job = entry.jobHandle;
    if (job == null) {
      // When no Job Object is attached, require a valid descendant snapshot
      // rather than trusting root exit alone.
      return entry.descendantSnapshotValid;
    }

    final accounting = calloc<_JobObjectBasicAccountingInformation>();
    try {
      final queried = QueryInformationJobObject(
        job,
        JobObjectBasicAccountingInformation,
        accounting,
        sizeOf<_JobObjectBasicAccountingInformation>(),
        nullptr,
      );
      if (!queried.value) return false;
      return accounting.ref.activeProcesses == 0;
    } finally {
      calloc.free(accounting);
    }
  }

  bool _isPidAlive(int pid) {
    final opened = OpenProcess(
      const PROCESS_ACCESS_RIGHTS(
        _processQueryLimitedInformation | _synchronize,
      ),
      false,
      pid,
    );
    if (opened.value.address == 0) return false;
    try {
      return WaitForSingleObject(opened.value, 0).value != WAIT_OBJECT_0;
    } finally {
      CloseHandle(opened.value);
    }
  }

  Set<int>? _snapshotDescendantPids(int rootPid) {
    final toolhelp = _Toolhelp32.instance;
    final snapshot = toolhelp.createSnapshot(_th32csSnapProcess, 0);
    if (snapshot.address == 0 || snapshot.address == _invalidHandleValue) {
      return null;
    }

    final entry = calloc<_ProcessEntry32W>();
    try {
      entry.ref.dwSize = sizeOf<_ProcessEntry32W>();
      if (toolhelp.first(snapshot, entry) == 0) {
        return const <int>{};
      }

      final childrenByParent = <int, List<int>>{};
      do {
        final pid = entry.ref.th32ProcessID;
        final ppid = entry.ref.th32ParentProcessID;
        if (pid > 0 && pid != ppid) {
          (childrenByParent[ppid] ??= <int>[]).add(pid);
        }
      } while (toolhelp.next(snapshot, entry) != 0);

      final descendants = <int>{};
      final queue = <int>[rootPid];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final children = childrenByParent[current];
        if (children == null) continue;
        for (final child in children) {
          if (descendants.add(child)) {
            queue.add(child);
          }
        }
      }
      return descendants;
    } finally {
      calloc.free(entry);
      CloseHandle(HANDLE(snapshot));
    }
  }
}
