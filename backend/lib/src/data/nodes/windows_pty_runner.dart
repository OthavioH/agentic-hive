import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:ffi/ffi.dart';

const int _procThreadAttributePseudoConsole = 0x00020016;
const int _extendedStartupInfoPresent = 0x00080000;
const int _createUnicodeEnvironment = 0x00000400;
const int _createSuspended = 0x00000004;
const int _startfUseStdHandles = 0x00000100;
const int _infinite = 0xFFFFFFFF;
const int _invalidHandleValue = -1;

final class _StartupInfoW extends Struct {
  @Uint32()
  external int cb;

  external Pointer<Utf16> lpReserved;
  external Pointer<Utf16> lpDesktop;
  external Pointer<Utf16> lpTitle;

  @Uint32()
  external int dwX;
  @Uint32()
  external int dwY;
  @Uint32()
  external int dwXSize;
  @Uint32()
  external int dwYSize;
  @Uint32()
  external int dwXCountChars;
  @Uint32()
  external int dwYCountChars;
  @Uint32()
  external int dwFillAttribute;
  @Uint32()
  external int dwFlags;

  @Uint16()
  external int wShowWindow;
  @Uint16()
  external int cbReserved2;

  external Pointer<Uint8> lpReserved2;

  @IntPtr()
  external int hStdInput;
  @IntPtr()
  external int hStdOutput;
  @IntPtr()
  external int hStdError;
}

final class _StartupInfoExW extends Struct {
  external _StartupInfoW startupInfo;
  external Pointer<Void> lpAttributeList;
}

final class _ProcessInformation extends Struct {
  @IntPtr()
  external int hProcess;
  @IntPtr()
  external int hThread;

  @Uint32()
  external int dwProcessId;
  @Uint32()
  external int dwThreadId;
}

typedef _CreatePipeNative = Int32 Function(
  Pointer<IntPtr> hReadPipe,
  Pointer<IntPtr> hWritePipe,
  Pointer<Void> lpPipeAttributes,
  Uint32 nSize,
);
typedef _CreatePipeDart = int Function(
  Pointer<IntPtr> hReadPipe,
  Pointer<IntPtr> hWritePipe,
  Pointer<Void> lpPipeAttributes,
  int nSize,
);

typedef _CreatePseudoConsoleNative = Int32 Function(
  Uint32 size,
  IntPtr hInput,
  IntPtr hOutput,
  Uint32 dwFlags,
  Pointer<IntPtr> phPC,
);
typedef _CreatePseudoConsoleDart = int Function(
  int size,
  int hInput,
  int hOutput,
  int dwFlags,
  Pointer<IntPtr> phPC,
);

typedef _ResizePseudoConsoleNative = Int32 Function(IntPtr hPC, Uint32 size);
typedef _ResizePseudoConsoleDart = int Function(int hPC, int size);

typedef _ClosePseudoConsoleNative = Void Function(IntPtr hPC);
typedef _ClosePseudoConsoleDart = void Function(int hPC);

typedef _InitProcThreadAttrListNative = Int32 Function(
  Pointer<Void> lpAttributeList,
  Uint32 dwAttributeCount,
  Uint32 dwFlags,
  Pointer<UintPtr> lpSize,
);
typedef _InitProcThreadAttrListDart = int Function(
  Pointer<Void> lpAttributeList,
  int dwAttributeCount,
  int dwFlags,
  Pointer<UintPtr> lpSize,
);

typedef _UpdateProcThreadAttrNative = Int32 Function(
  Pointer<Void> lpAttributeList,
  Uint32 dwFlags,
  UintPtr attribute,
  Pointer<Void> lpValue,
  UintPtr cbSize,
  Pointer<Void> lpPreviousValue,
  Pointer<UintPtr> lpReturnSize,
);
typedef _UpdateProcThreadAttrDart = int Function(
  Pointer<Void> lpAttributeList,
  int dwFlags,
  int attribute,
  Pointer<Void> lpValue,
  int cbSize,
  Pointer<Void> lpPreviousValue,
  Pointer<UintPtr> lpReturnSize,
);

typedef _DeleteProcThreadAttrListNative = Void Function(
  Pointer<Void> lpAttributeList,
);
typedef _DeleteProcThreadAttrListDart = void Function(
  Pointer<Void> lpAttributeList,
);

typedef _CreateProcessWNative = Int32 Function(
  Pointer<Utf16> lpApplicationName,
  Pointer<Utf16> lpCommandLine,
  Pointer<Void> lpProcessAttributes,
  Pointer<Void> lpThreadAttributes,
  Int32 bInheritHandles,
  Uint32 dwCreationFlags,
  Pointer<Void> lpEnvironment,
  Pointer<Utf16> lpCurrentDirectory,
  Pointer<_StartupInfoExW> lpStartupInfo,
  Pointer<_ProcessInformation> lpProcessInformation,
);
typedef _CreateProcessWDart = int Function(
  Pointer<Utf16> lpApplicationName,
  Pointer<Utf16> lpCommandLine,
  Pointer<Void> lpProcessAttributes,
  Pointer<Void> lpThreadAttributes,
  int bInheritHandles,
  int dwCreationFlags,
  Pointer<Void> lpEnvironment,
  Pointer<Utf16> lpCurrentDirectory,
  Pointer<_StartupInfoExW> lpStartupInfo,
  Pointer<_ProcessInformation> lpProcessInformation,
);

typedef _ResumeThreadNative = Uint32 Function(IntPtr hThread);
typedef _ResumeThreadDart = int Function(int hThread);

typedef _ReadFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);
typedef _ReadFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);

typedef _WriteFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);
typedef _WriteFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

typedef _WaitForSingleObjectNative = Uint32 Function(
  IntPtr hHandle,
  Uint32 dwMilliseconds,
);
typedef _WaitForSingleObjectDart = int Function(
  int hHandle,
  int dwMilliseconds,
);

typedef _GetExitCodeProcessNative = Int32 Function(
  IntPtr hProcess,
  Pointer<Uint32> lpExitCode,
);
typedef _GetExitCodeProcessDart = int Function(
  int hProcess,
  Pointer<Uint32> lpExitCode,
);

typedef _TerminateProcessNative = Int32 Function(
  IntPtr hProcess,
  Uint32 uExitCode,
);
typedef _TerminateProcessDart = int Function(int hProcess, int uExitCode);

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

final class _Kernel32 {
  new _() {
    final lib = DynamicLibrary.open('kernel32.dll');
    createPipe = lib.lookupFunction<_CreatePipeNative, _CreatePipeDart>(
      'CreatePipe',
    );
    createPseudoConsole = lib
        .lookupFunction<_CreatePseudoConsoleNative, _CreatePseudoConsoleDart>(
          'CreatePseudoConsole',
        );
    resizePseudoConsole = lib
        .lookupFunction<_ResizePseudoConsoleNative, _ResizePseudoConsoleDart>(
          'ResizePseudoConsole',
        );
    closePseudoConsole = lib
        .lookupFunction<_ClosePseudoConsoleNative, _ClosePseudoConsoleDart>(
          'ClosePseudoConsole',
        );
    initAttrList = lib
        .lookupFunction<
          _InitProcThreadAttrListNative,
          _InitProcThreadAttrListDart
        >('InitializeProcThreadAttributeList');
    updateAttrList = lib
        .lookupFunction<_UpdateProcThreadAttrNative, _UpdateProcThreadAttrDart>(
          'UpdateProcThreadAttribute',
        );
    deleteAttrList = lib
        .lookupFunction<
          _DeleteProcThreadAttrListNative,
          _DeleteProcThreadAttrListDart
        >('DeleteProcThreadAttributeList');
    createProcessW = lib
        .lookupFunction<_CreateProcessWNative, _CreateProcessWDart>(
          'CreateProcessW',
        );
    resumeThread = lib.lookupFunction<_ResumeThreadNative, _ResumeThreadDart>(
      'ResumeThread',
    );
    readFile = lib.lookupFunction<_ReadFileNative, _ReadFileDart>('ReadFile');
    writeFile = lib.lookupFunction<_WriteFileNative, _WriteFileDart>(
      'WriteFile',
    );
    closeHandle = lib.lookupFunction<_CloseHandleNative, _CloseHandleDart>(
      'CloseHandle',
    );
    waitForSingleObject = lib
        .lookupFunction<_WaitForSingleObjectNative, _WaitForSingleObjectDart>(
          'WaitForSingleObject',
        );
    getExitCodeProcess = lib
        .lookupFunction<_GetExitCodeProcessNative, _GetExitCodeProcessDart>(
          'GetExitCodeProcess',
        );
    terminateProcess = lib
        .lookupFunction<_TerminateProcessNative, _TerminateProcessDart>(
          'TerminateProcess',
        );
    getLastError = lib.lookupFunction<_GetLastErrorNative, _GetLastErrorDart>(
      'GetLastError',
    );
  }

  static final _Kernel32 instance = ._();

  late final _CreatePipeDart createPipe;
  late final _CreatePseudoConsoleDart createPseudoConsole;
  late final _ResizePseudoConsoleDart resizePseudoConsole;
  late final _ClosePseudoConsoleDart closePseudoConsole;
  late final _InitProcThreadAttrListDart initAttrList;
  late final _UpdateProcThreadAttrDart updateAttrList;
  late final _DeleteProcThreadAttrListDart deleteAttrList;
  late final _CreateProcessWDart createProcessW;
  late final _ResumeThreadDart resumeThread;
  late final _ReadFileDart readFile;
  late final _WriteFileDart writeFile;
  late final _CloseHandleDart closeHandle;
  late final _WaitForSingleObjectDart waitForSingleObject;
  late final _GetExitCodeProcessDart getExitCodeProcess;
  late final _TerminateProcessDart terminateProcess;
  late final _GetLastErrorDart getLastError;
}

int _packCoord(int cols, int rows) => (rows << 16) | (cols & 0xFFFF);

void _pipeReaderIsolate(({int handle, SendPort port}) args) {
  final k32 = _Kernel32.instance;
  const bufSize = 4096;
  final buffer = calloc<Uint8>(bufSize);
  final bytesRead = calloc<Uint32>();
  try {
    while (true) {
      final ok = k32.readFile(args.handle, buffer, bufSize, bytesRead, nullptr);
      final count = bytesRead.value;
      if (ok == 0 || count == 0) {
        break;
      }
      args.port.send(Uint8List.fromList(buffer.asTypedList(count)));
    }
  } finally {
    calloc
      ..free(buffer)
      ..free(bytesRead);
    args.port.send(null);
  }
}

int _waitForProcessExitIsolate(int processHandle) {
  final k32 = _Kernel32.instance;
  k32.waitForSingleObject(processHandle, _infinite);
  final codePtr = calloc<Uint32>();
  try {
    if (k32.getExitCodeProcess(processHandle, codePtr) != 0) {
      return codePtr.value;
    }
    return -1;
  } finally {
    calloc.free(codePtr);
  }
}

Future<int> _waitForProcessExitAsync(int processHandle) =>
    Isolate.run(() => _waitForProcessExitIsolate(processHandle));

final class _WindowsPtySessionHandle implements PtySessionHandle {
  new({
    required this.key,
    required this._hPC,
    required this._hInputWrite,
    required this._hProcess,
    required this._onTerminate,
  });

  @override
  final PtySessionKey key;

  int _hPC;
  int _hInputWrite;
  int _hProcess;
  final Future<void> Function() _onTerminate;
  bool _active = true;

  @override
  bool get isActive => _active;

  void markClosed() {
    _active = false;
  }

  void closeConPtyAndPipes(int hOutputRead) {
    final k32 = _Kernel32.instance;
    if (_hPC != 0) {
      k32.closePseudoConsole(_hPC);
      _hPC = 0;
    }
    if (_hInputWrite != 0 && _hInputWrite != _invalidHandleValue) {
      k32.closeHandle(_hInputWrite);
      _hInputWrite = 0;
    }
    if (hOutputRead != 0 && hOutputRead != _invalidHandleValue) {
      k32.closeHandle(hOutputRead);
    }
  }

  void closeProcessHandle() {
    if (_hProcess != 0 && _hProcess != _invalidHandleValue) {
      _Kernel32.instance.closeHandle(_hProcess);
      _hProcess = 0;
    }
  }

  @override
  Future<void> writeInput(List<int> bytes) async {
    if (!_active || bytes.isEmpty || _hInputWrite == 0) return;
    final k32 = _Kernel32.instance;
    final buf = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final ok = k32.writeFile(
          _hInputWrite,
          buf + offset,
          bytes.length - offset,
          written,
          nullptr,
        );
        if (ok == 0 || written.value == 0) break;
        offset += written.value;
      }
    } finally {
      calloc
        ..free(buf)
        ..free(written);
    }
  }

  @override
  Future<void> resize(int cols, int rows) async {
    if (!_active || _hPC == 0 || cols <= 0 || rows <= 0) return;
    _Kernel32.instance.resizePseudoConsole(_hPC, _packCoord(cols, rows));
  }

  @override
  Future<void> terminate() async {
    if (!_active) return;
    await _onTerminate();
  }
}

/// Windows ConPTY implementation of [PtyRunner] using `dart:ffi`
/// (`CreatePseudoConsole` + `STARTUPINFOEXW` + `ProcessTreeTracker`).
final class WindowsPtyRunner implements PtyRunner {
  /// Creates a Windows ConPTY runner.
  const new({
    this.processTracker,
    this.processTreeKiller,
    this.sessionRegistry,
    this.maxOutputLength = defaultMaxOutputLength,
    this.drainTimeout = defaultDrainTimeout,
  });

  /// Default retained stdout cap (1 MiB of characters).
  static const int defaultMaxOutputLength = 1024 * 1024;

  /// Default maximum time to wait for PTY output drain after exit.
  static const Duration defaultDrainTimeout = Duration(seconds: 2);

  /// Optional tracker registering spawned processes for cancellation.
  final ProcessTreeTracker? processTracker;

  /// Optional process-tree killer used on timeout or explicit termination.
  final ProcessTreeKiller? processTreeKiller;

  /// Optional session registry for WebSocket streaming and scrollback.
  final PtySessionRegistry? sessionRegistry;

  /// Maximum number of characters retained in [ProcessExecutionResult.stdout].
  final int maxOutputLength;

  /// Maximum time to wait for reader drain after process exit.
  final Duration drainTimeout;

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    final tracker = processTracker;
    final trackedRunId = invocation.runId;
    if (tracker != null &&
        trackedRunId != null &&
        tracker.isRunCancelling(trackedRunId)) {
      return FailureResult(
        NodeExecutionFailure(
          'Refusing to start "${invocation.executable}": run "$trackedRunId" '
          'is cancelling.',
        ),
      );
    }

    final k32 = _Kernel32.instance;
    final hInputReadPtr = calloc<IntPtr>();
    final hInputWritePtr = calloc<IntPtr>();
    final hOutputReadPtr = calloc<IntPtr>();
    final hOutputWritePtr = calloc<IntPtr>();
    final hPcPtr = calloc<IntPtr>();

    var hInputRead = 0;
    var hInputWrite = 0;
    var hOutputRead = 0;
    var hOutputWrite = 0;
    var hPC = 0;

    try {
      if (k32.createPipe(hInputReadPtr, hInputWritePtr, nullptr, 0) == 0 ||
          k32.createPipe(hOutputReadPtr, hOutputWritePtr, nullptr, 0) == 0) {
        final err = k32.getLastError();
        return FailureResult(
          NodeExecutionFailure(
            'Failed to create ConPTY pipes (Win32 error $err).',
          ),
        );
      }
      hInputRead = hInputReadPtr.value;
      hInputWrite = hInputWritePtr.value;
      hOutputRead = hOutputReadPtr.value;
      hOutputWrite = hOutputWritePtr.value;

      final hr = k32.createPseudoConsole(
        _packCoord(invocation.cols, invocation.rows),
        hInputRead,
        hOutputWrite,
        0,
        hPcPtr,
      );
      if (hr != 0) {
        final hex = hr.toRadixString(16);
        return FailureResult(
          NodeExecutionFailure(
            'CreatePseudoConsole failed with HRESULT 0x$hex.',
          ),
        );
      }
      hPC = hPcPtr.value;

      // Close the child-side pipe ends in the parent so closing ConPTY sends
      // EOF to hOutputRead.
      k32.closeHandle(hInputRead);
      hInputRead = 0;
      k32.closeHandle(hOutputWrite);
      hOutputWrite = 0;
    } finally {
      calloc
        ..free(hInputReadPtr)
        ..free(hInputWritePtr)
        ..free(hOutputReadPtr)
        ..free(hOutputWritePtr)
        ..free(hPcPtr);
      if (hPC == 0) {
        if (hInputRead != 0) k32.closeHandle(hInputRead);
        if (hInputWrite != 0) k32.closeHandle(hInputWrite);
        if (hOutputRead != 0) k32.closeHandle(hOutputRead);
        if (hOutputWrite != 0) k32.closeHandle(hOutputWrite);
      }
    }

    final attrSizePtr = calloc<UintPtr>();
    Pointer<Void> attrList = nullptr;
    final siEx = calloc<_StartupInfoExW>();
    final pi = calloc<_ProcessInformation>();
    final cmdLinePtr = _buildCommandLine(
      invocation.executable,
      invocation.arguments,
    ).toNativeUtf16();
    final cwdPtr = invocation.workingDirectory.toNativeUtf16();
    final envBlockPtr = _buildEnvironmentBlock(invocation.environment);

    var hProcess = 0;
    var hThread = 0;
    var pid = 0;

    try {
      k32.initAttrList(nullptr, 1, 0, attrSizePtr);
      attrList = calloc<Uint8>(attrSizePtr.value).cast<Void>();
      if (k32.initAttrList(attrList, 1, 0, attrSizePtr) == 0) {
        return FailureResult(
          NodeExecutionFailure(
            'InitializeProcThreadAttributeList failed (Win32 error '
            '${k32.getLastError()}).',
          ),
        );
      }
      if (k32.updateAttrList(
            attrList,
            0,
            _procThreadAttributePseudoConsole,
            Pointer<Void>.fromAddress(hPC),
            sizeOf<IntPtr>(),
            nullptr,
            nullptr,
          ) ==
          0) {
        return FailureResult(
          NodeExecutionFailure(
            'UpdateProcThreadAttribute failed (Win32 error '
            '${k32.getLastError()}).',
          ),
        );
      }

      siEx.ref.startupInfo.cb = sizeOf<_StartupInfoExW>();
      siEx.ref.startupInfo.dwFlags = _startfUseStdHandles;
      siEx.ref.lpAttributeList = attrList;

      const flags =
          _extendedStartupInfoPresent |
          _createUnicodeEnvironment |
          _createSuspended;
      final created = k32.createProcessW(
        nullptr,
        cmdLinePtr,
        nullptr,
        nullptr,
        0,
        flags,
        envBlockPtr,
        cwdPtr,
        siEx,
        pi,
      );
      if (created == 0) {
        final err = k32.getLastError();
        return FailureResult(
          NodeExecutionFailure(
            'Failed to start "${invocation.executable}" in ConPTY '
            '(Win32 error $err).',
          ),
        );
      }

      hProcess = pi.ref.hProcess;
      hThread = pi.ref.hThread;
      pid = pi.ref.dwProcessId;
    } finally {
      if (attrList != nullptr) {
        k32.deleteAttrList(attrList);
        calloc.free(attrList);
      }
      calloc
        ..free(attrSizePtr)
        ..free(siEx)
        ..free(pi)
        ..free(cmdLinePtr)
        ..free(cwdPtr)
        ..free(envBlockPtr);

      if (hProcess == 0) {
        k32
          ..closePseudoConsole(hPC)
          ..closeHandle(hInputWrite)
          ..closeHandle(hOutputRead);
      }
    }

    final exitCompleter = Completer<int>();
    final sessionKey = (
      runId: invocation.runId ?? '',
      nodeId: invocation.nodeId ?? '',
      attempt: invocation.attempt,
    );

    Future<void> terminateProcessTree() async {
      if (processTreeKiller != null && trackedRunId != null) {
        await processTreeKiller!.killTree(
          runId: trackedRunId,
          nodeId: invocation.nodeId,
        );
      } else {
        k32.terminateProcess(hProcess, 1);
      }
    }

    final handle = _WindowsPtySessionHandle(
      key: sessionKey,
      hPC: hPC,
      hInputWrite: hInputWrite,
      hProcess: hProcess,
      onTerminate: terminateProcessTree,
    );

    if (tracker != null && trackedRunId != null) {
      tracker.trackPid(
        runId: trackedRunId,
        nodeId: invocation.nodeId ?? '',
        pid: pid,
        exitCode: exitCompleter.future,
      );
      if (tracker.isRunCancelling(trackedRunId)) {
        await terminateProcessTree();
      }
    }

    if (invocation.runId != null) {
      sessionRegistry?.registerSession(handle);
    }

    final receivePort = ReceivePort();
    final readerDone = Completer<void>();
    final stdoutBuffer = StringBuffer();
    final lineBuffer = StringBuffer();
    const utf8Decoder = Utf8Decoder(allowMalformed: true);
    var truncated = false;

    receivePort.listen((message) {
      if (message == null) {
        if (!readerDone.isCompleted) readerDone.complete();
        return;
      }
      final bytes = message as Uint8List;
      if (invocation.runId != null) {
        sessionRegistry?.appendOutput(sessionKey, bytes);
      }

      final text = utf8Decoder.convert(bytes);
      _emitLines(text, lineBuffer, onOutput);

      if (!truncated && text.isNotEmpty) {
        final remaining = maxOutputLength - stdoutBuffer.length;
        if (remaining <= 0) {
          truncated = true;
        } else if (text.length <= remaining) {
          stdoutBuffer.write(text);
        } else {
          stdoutBuffer.write(text.substring(0, remaining));
          truncated = true;
        }
      }
    });

    await Isolate.spawn(_pipeReaderIsolate, (
      handle: hOutputRead,
      port: receivePort.sendPort,
    ), errorsAreFatal: false);

    k32
      ..resumeThread(hThread)
      ..closeHandle(hThread);

    if (invocation.initialInput case final input? when input.isNotEmpty) {
      await handle.writeInput(utf8.encode(input));
    }

    final waitFuture = _waitForProcessExitAsync(hProcess);
    var timedOut = false;
    final int exitCode;
    try {
      final timeout = invocation.timeout;
      if (timeout != null) {
        exitCode = await waitFuture.timeout(
          timeout,
          onTimeout: () async {
            timedOut = true;
            await terminateProcessTree();
            await waitFuture.timeout(drainTimeout, onTimeout: () => -1);
            return -1;
          },
        );
      } else {
        exitCode = await waitFuture;
      }
    } finally {
      if (!exitCompleter.isCompleted) {
        exitCompleter.complete(-1);
      }
      handle
        ..markClosed()
        ..closeConPtyAndPipes(hOutputRead);
      if (tracker != null && trackedRunId != null) {
        tracker.untrackPid(pid);
      }
      await readerDone.future.timeout(drainTimeout, onTimeout: () {});
      receivePort.close();
      if (invocation.runId != null) {
        await sessionRegistry?.unregisterSession(sessionKey);
      }
      handle.closeProcessHandle();
    }

    if (lineBuffer.isNotEmpty) {
      onOutput?.call('stdout', lineBuffer.toString());
    }

    return Success(
      ProcessExecutionResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        timedOut: timedOut,
      ),
    );
  }
}

void _emitLines(
  String text,
  StringBuffer lineBuffer,
  NodeOutputCallback? onOutput,
) {
  if (onOutput == null || text.isEmpty) return;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '\n') {
      var line = lineBuffer.toString();
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      onOutput('stdout', line);
      lineBuffer.clear();
    } else {
      lineBuffer.write(ch);
    }
  }
}

String _buildCommandLine(String executable, List<String> arguments) {
  final parts = <String>[_quoteWinArg(executable)];
  for (final arg in arguments) {
    parts.add(_quoteWinArg(arg));
  }
  return parts.join(' ');
}

String _quoteWinArg(String arg) {
  if (arg.isNotEmpty &&
      !arg.contains(' ') &&
      !arg.contains('\t') &&
      !arg.contains('"')) {
    return arg;
  }
  final buffer = StringBuffer('"');
  var backslashes = 0;
  for (var i = 0; i < arg.length; i++) {
    final ch = arg[i];
    if (ch == r'\') {
      backslashes++;
    } else if (ch == '"') {
      buffer
        ..write(r'\' * (backslashes * 2 + 1))
        ..write('"');
      backslashes = 0;
    } else {
      if (backslashes > 0) {
        buffer.write(r'\' * backslashes);
        backslashes = 0;
      }
      buffer.write(ch);
    }
  }
  if (backslashes > 0) {
    buffer.write(r'\' * (backslashes * 2));
  }
  buffer.write('"');
  return buffer.toString();
}

Pointer<Void> _buildEnvironmentBlock(Map<String, String> overrides) {
  final merged = <String, String>{...Platform.environment, ...overrides};
  final buffer = StringBuffer();
  for (final entry in merged.entries) {
    buffer
      ..write(entry.key)
      ..write('=')
      ..write(entry.value)
      ..writeCharCode(0);
  }
  buffer.writeCharCode(0);
  final units = buffer.toString().codeUnits;
  final ptr = calloc<Uint16>(units.length);
  ptr.asTypedList(units.length).setAll(0, units);
  return ptr.cast<Void>();
}
