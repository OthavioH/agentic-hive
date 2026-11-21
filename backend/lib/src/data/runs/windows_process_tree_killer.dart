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

final class _TrackedWindowsProcess {
  new({
    required this.runId,
    required this.nodeId,
    required this.process,
    required this.jobHandle,
    required this.processHandle,
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
  bool exited = false;
  bool killing = false;

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
/// Objects (`dart:ffi` + `package:win32`) with `taskkill /T /F` fallback
/// (ADR 0009, ADR 0012).
final class WindowsProcessTreeKiller
    implements ProcessTreeKiller, ProcessTreeTracker {
  /// Creates a Windows process-tree killer.
  new({
    this.confirmationTimeout = const Duration(seconds: 5),
    this.pollInterval = const Duration(milliseconds: 25),
  });

  static final _log = Logger('process_tree_killer.windows');

  /// Maximum time to wait for confirmation that every process in the Job
  /// Object and the root handle have exited after forced termination.
  final Duration confirmationTimeout;

  /// Interval between exit-confirmation polls.
  final Duration pollInterval;

  final List<_TrackedWindowsProcess> _tracked = <_TrackedWindowsProcess>[];

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

    _tracked.add(
      _TrackedWindowsProcess(
        runId: runId,
        nodeId: nodeId,
        process: process,
        jobHandle: jobHandle,
        processHandle: processHandle,
      ),
    );
  }

  @override
  void untrack(Process process) {
    for (var i = _tracked.length - 1; i >= 0; i--) {
      final entry = _tracked[i];
      if (entry.process.pid == process.pid && !entry.killing) {
        entry.closeHandles();
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

    for (final entry in targets) {
      entry.killing = true;
      await _terminateEntry(entry);
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
    final job = entry.jobHandle;
    if (job != null) {
      final terminated = TerminateJobObject(job, 1);
      if (terminated.value) return;
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
  }

  bool _isConfirmedExited(_TrackedWindowsProcess entry) {
    final procHandle = entry.processHandle;
    final rootExited =
        entry.exited ||
        (procHandle != null &&
            WaitForSingleObject(procHandle, 0).value == WAIT_OBJECT_0);
    if (!rootExited) return false;

    final job = entry.jobHandle;
    if (job == null) return true;

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
}
