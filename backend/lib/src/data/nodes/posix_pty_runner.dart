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
import 'package:path/path.dart' as p;

const int _oRdwr = 0x0002;
const int _oNocttyLinux = 0x0100;
const int _oNocttyMacos = 0x20000;
const int _eintr = 4;
const int _tiocswinszLinux = 0x5414;
const int _tiocswinszMacos = 0x80087467;
const int _tiocscttyLinux = 0x540E;
const int _tiocscttyMacos = 0x20007461;
const int _sigKill = 9;

final class _WinSize extends Struct {
  @Uint16()
  external int wsRow;

  @Uint16()
  external int wsCol;

  @Uint16()
  external int wsXpixel;

  @Uint16()
  external int wsYpixel;
}

typedef _PosixOpenptNative = Int32 Function(Int32 flags);
typedef _PosixOpenptDart = int Function(int flags);

typedef _GrantptNative = Int32 Function(Int32 fd);
typedef _GrantptDart = int Function(int fd);

typedef _UnlockptNative = Int32 Function(Int32 fd);
typedef _UnlockptDart = int Function(int fd);

typedef _PtsnameNative = Pointer<Utf8> Function(Int32 fd);
typedef _PtsnameDart = Pointer<Utf8> Function(int fd);

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _OpenDart = int Function(Pointer<Utf8> path, int flags);

typedef _CloseNative = Int32 Function(Int32 fd);
typedef _CloseDart = int Function(int fd);

typedef _ReadNative = IntPtr Function(
  Int32 fd,
  Pointer<Uint8> buf,
  UintPtr count,
);
typedef _ReadDart = int Function(int fd, Pointer<Uint8> buf, int count);

typedef _WriteNative = IntPtr Function(
  Int32 fd,
  Pointer<Uint8> buf,
  UintPtr count,
);
typedef _WriteDart = int Function(int fd, Pointer<Uint8> buf, int count);

typedef _IoctlNative = Int32 Function(
  Int32 fd,
  Uint64 request,
  Pointer<Void> arg,
);
typedef _IoctlDart = int Function(int fd, int request, Pointer<Void> arg);

typedef _ForkNative = Int32 Function();
typedef _ForkDart = int Function();

typedef _SetsidNative = Int32 Function();
typedef _SetsidDart = int Function();

typedef _Dup2Native = Int32 Function(Int32 oldFd, Int32 newFd);
typedef _Dup2Dart = int Function(int oldFd, int newFd);

typedef _ChdirNative = Int32 Function(Pointer<Utf8> path);
typedef _ChdirDart = int Function(Pointer<Utf8> path);

typedef _ExecveNative = Int32 Function(
  Pointer<Utf8> pathname,
  Pointer<Pointer<Utf8>> argv,
  Pointer<Pointer<Utf8>> envp,
);
typedef _ExecveDart = int Function(
  Pointer<Utf8> pathname,
  Pointer<Pointer<Utf8>> argv,
  Pointer<Pointer<Utf8>> envp,
);

typedef _ExitNative = Void Function(Int32 status);
typedef _ExitDart = void Function(int status);

typedef _WaitpidNative = Int32 Function(
  Int32 pid,
  Pointer<Int32> status,
  Int32 options,
);
typedef _WaitpidDart = int Function(
  int pid,
  Pointer<Int32> status,
  int options,
);

typedef _KillNative = Int32 Function(Int32 pid, Int32 sig);
typedef _KillDart = int Function(int pid, int sig);

typedef _ErrnoPtrNative = Pointer<Int32> Function();
typedef _ErrnoPtrDart = Pointer<Int32> Function();

final class _PosixLibc {
  new _(String errnoSymbol) {
    final lib = DynamicLibrary.process();
    posixOpenpt = lib.lookupFunction<_PosixOpenptNative, _PosixOpenptDart>(
      'posix_openpt',
    );
    grantpt = lib.lookupFunction<_GrantptNative, _GrantptDart>('grantpt');
    unlockpt = lib.lookupFunction<_UnlockptNative, _UnlockptDart>('unlockpt');
    ptsname = lib.lookupFunction<_PtsnameNative, _PtsnameDart>('ptsname');
    open = lib.lookupFunction<_OpenNative, _OpenDart>('open');
    close = lib.lookupFunction<_CloseNative, _CloseDart>('close');
    read = lib.lookupFunction<_ReadNative, _ReadDart>('read');
    write = lib.lookupFunction<_WriteNative, _WriteDart>('write');
    ioctl = lib.lookupFunction<_IoctlNative, _IoctlDart>('ioctl');
    fork = lib.lookupFunction<_ForkNative, _ForkDart>('fork');
    setsid = lib.lookupFunction<_SetsidNative, _SetsidDart>('setsid');
    dup2 = lib.lookupFunction<_Dup2Native, _Dup2Dart>('dup2');
    chdir = lib.lookupFunction<_ChdirNative, _ChdirDart>('chdir');
    execve = lib.lookupFunction<_ExecveNative, _ExecveDart>('execve');
    exit = lib.lookupFunction<_ExitNative, _ExitDart>('_exit');
    waitpid = lib.lookupFunction<_WaitpidNative, _WaitpidDart>('waitpid');
    kill = lib.lookupFunction<_KillNative, _KillDart>('kill');
    _errnoPtr = lib.lookupFunction<_ErrnoPtrNative, _ErrnoPtrDart>(errnoSymbol);
  }

  late final _PosixOpenptDart posixOpenpt;
  late final _GrantptDart grantpt;
  late final _UnlockptDart unlockpt;
  late final _PtsnameDart ptsname;
  late final _OpenDart open;
  late final _CloseDart close;
  late final _ReadDart read;
  late final _WriteDart write;
  late final _IoctlDart ioctl;
  late final _ForkDart fork;
  late final _SetsidDart setsid;
  late final _Dup2Dart dup2;
  late final _ChdirDart chdir;
  late final _ExecveDart execve;
  late final _ExitDart exit;
  late final _WaitpidDart waitpid;
  late final _KillDart kill;
  late final _ErrnoPtrDart _errnoPtr;

  int get errno => _errnoPtr().value;
}

/// OS-specific POSIX PTY ioctl/flag constants (Linux vs macOS).
final class PosixPtyConfig {
  /// Creates a POSIX PTY configuration.
  const new({
    required this.oNoctty,
    required this.tiocswinsz,
    required this.tiocsctty,
    required this.errnoSymbol,
  });

  /// Linux PTY constants.
  static const PosixPtyConfig linux = PosixPtyConfig(
    oNoctty: _oNocttyLinux,
    tiocswinsz: _tiocswinszLinux,
    tiocsctty: _tiocscttyLinux,
    errnoSymbol: '__errno_location',
  );

  /// macOS PTY constants.
  static const PosixPtyConfig macos = PosixPtyConfig(
    oNoctty: _oNocttyMacos,
    tiocswinsz: _tiocswinszMacos,
    tiocsctty: _tiocscttyMacos,
    errnoSymbol: '__error',
  );

  /// `O_NOCTTY` open flag.
  final int oNoctty;

  /// `TIOCSWINSZ` ioctl request.
  final int tiocswinsz;

  /// `TIOCSCTTY` ioctl request.
  final int tiocsctty;

  /// C runtime errno lookup symbol (`__errno_location` or `__error`).
  final String errnoSymbol;
}

void _posixReaderIsolate(({int fd, String errnoSymbol, SendPort port}) args) {
  final libc = _PosixLibc._(args.errnoSymbol);
  const bufSize = 4096;
  final buf = calloc<Uint8>(bufSize);
  try {
    while (true) {
      final n = libc.read(args.fd, buf, bufSize);
      if (n > 0) {
        args.port.send(Uint8List.fromList(buf.asTypedList(n)));
      } else if (n == 0) {
        break;
      } else if (libc.errno != _eintr) {
        break;
      }
    }
  } finally {
    calloc.free(buf);
    args.port.send(null);
  }
}

int _waitpidIsolate(({int pid, String errnoSymbol}) args) {
  final libc = _PosixLibc._(args.errnoSymbol);
  final statusPtr = calloc<Int32>();
  try {
    while (true) {
      final waited = libc.waitpid(args.pid, statusPtr, 0);
      if (waited == -1) {
        if (libc.errno == _eintr) continue;
        return -1;
      }
      final status = statusPtr.value;
      final termSig = status & 0x7F;
      if (termSig == 0) {
        return (status >> 8) & 0xFF;
      }
      return 128 + termSig;
    }
  } finally {
    calloc.free(statusPtr);
  }
}

Future<int> _waitpidAsync(int pid, String errnoSymbol) =>
    Isolate.run(() => _waitpidIsolate((pid: pid, errnoSymbol: errnoSymbol)));

final class _PosixPtySessionHandle implements PtySessionHandle {
  new({
    required this.key,
    required this._masterFd,
    required this.libc,
    required this.tiocswinsz,
    required this._onTerminate,
  });

  @override
  final PtySessionKey key;

  int _masterFd;
  final _PosixLibc libc;
  final int tiocswinsz;
  final Future<void> Function() _onTerminate;
  bool _active = true;

  @override
  bool get isActive => _active;

  void markClosed() {
    _active = false;
  }

  void closeMasterFd() {
    if (_masterFd >= 0) {
      libc.close(_masterFd);
      _masterFd = -1;
    }
  }

  @override
  Future<void> writeInput(List<int> bytes) async {
    if (!_active || bytes.isEmpty || _masterFd < 0) return;
    final buf = calloc<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final written = libc.write(
          _masterFd,
          buf + offset,
          bytes.length - offset,
        );
        if (written <= 0) {
          if (written == -1 && libc.errno == _eintr) continue;
          break;
        }
        offset += written;
      }
    } finally {
      calloc.free(buf);
    }
  }

  @override
  Future<void> resize(int cols, int rows) async {
    if (!_active || _masterFd < 0 || cols <= 0 || rows <= 0) return;
    final winSize = calloc<_WinSize>();
    try {
      winSize.ref
        ..wsCol = cols
        ..wsRow = rows
        ..wsXpixel = 0
        ..wsYpixel = 0;
      libc.ioctl(_masterFd, tiocswinsz, winSize.cast<Void>());
    } finally {
      calloc.free(winSize);
    }
  }

  @override
  Future<void> terminate() async {
    if (!_active) return;
    await _onTerminate();
  }
}

/// POSIX (`openpty` / `posix_openpt`) implementation of [PtyRunner] for Linux
/// and macOS using `dart:ffi`.
final class PosixPtyRunner implements PtyRunner {
  /// Creates a POSIX PTY runner.
  const new({
    required this.config,
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

  /// Platform-specific POSIX PTY constants.
  final PosixPtyConfig config;

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

    final resolvedExecutable = _resolveExecutable(
      invocation.executable,
      invocation.environment,
    );
    if (resolvedExecutable == null) {
      return FailureResult(
        NodeExecutionFailure(
          'Failed to locate executable "${invocation.executable}" on PATH.',
        ),
      );
    }

    final libc = _PosixLibc._(config.errnoSymbol);
    final masterFd = libc.posixOpenpt(_oRdwr | config.oNoctty);
    if (masterFd < 0) {
      return FailureResult(
        NodeExecutionFailure('posix_openpt failed (errno ${libc.errno}).'),
      );
    }

    var slaveFd = -1;
    var pid = -1;

    final winSize = calloc<_WinSize>();
    final argv = _allocStringArray(<String>[
      resolvedExecutable,
      ...invocation.arguments,
    ]);
    final mergedEnv = <String, String>{
      ...Platform.environment,
      ...invocation.environment,
    };
    final envp = _allocStringArray(
      mergedEnv.entries.map((e) => '${e.key}=${e.value}').toList(),
    );
    final execPtr = resolvedExecutable.toNativeUtf8();
    final cwdPtr = invocation.workingDirectory.toNativeUtf8();

    try {
      if (libc.grantpt(masterFd) != 0 || libc.unlockpt(masterFd) != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'grantpt/unlockpt failed (errno ${libc.errno}).',
          ),
        );
      }

      final slaveNamePtr = libc.ptsname(masterFd);
      if (slaveNamePtr == nullptr) {
        return FailureResult(
          NodeExecutionFailure('ptsname failed (errno ${libc.errno}).'),
        );
      }

      slaveFd = libc.open(slaveNamePtr, _oRdwr | config.oNoctty);
      if (slaveFd < 0) {
        return FailureResult(
          NodeExecutionFailure('open(slave pty) failed (errno ${libc.errno}).'),
        );
      }

      winSize.ref
        ..wsCol = invocation.cols
        ..wsRow = invocation.rows
        ..wsXpixel = 0
        ..wsYpixel = 0;
      libc.ioctl(masterFd, config.tiocswinsz, winSize.cast<Void>());

      pid = libc.fork();
      if (pid < 0) {
        return FailureResult(
          NodeExecutionFailure('fork() failed (errno ${libc.errno}).'),
        );
      }

      if (pid == 0) {
        libc.close(masterFd);
        if (libc.setsid() < 0) {
          libc.exit(127);
        }
        libc
          ..ioctl(slaveFd, config.tiocsctty, nullptr)
          ..dup2(slaveFd, 0)
          ..dup2(slaveFd, 1)
          ..dup2(slaveFd, 2);
        if (slaveFd > 2) {
          libc.close(slaveFd);
        }
        if (libc.chdir(cwdPtr) != 0) {
          libc.exit(127);
        }
        libc
          ..execve(execPtr, argv, envp)
          ..exit(127);
      }
    } finally {
      if (slaveFd >= 0) {
        libc.close(slaveFd);
      }
      _freeStringArray(argv);
      _freeStringArray(envp);
      calloc
        ..free(winSize)
        ..free(execPtr)
        ..free(cwdPtr);

      if (pid <= 0) {
        libc.close(masterFd);
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
        libc.kill(-pid, _sigKill);
      }
    }

    final handle = _PosixPtySessionHandle(
      key: sessionKey,
      masterFd: masterFd,
      libc: libc,
      tiocswinsz: config.tiocswinsz,
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

    await Isolate.spawn(_posixReaderIsolate, (
      fd: masterFd,
      errnoSymbol: config.errnoSymbol,
      port: receivePort.sendPort,
    ), errorsAreFatal: false);

    if (invocation.initialInput case final input? when input.isNotEmpty) {
      await handle.writeInput(utf8.encode(input));
    }

    final waitFuture = _waitpidAsync(pid, config.errnoSymbol);
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
        ..closeMasterFd();
      if (tracker != null && trackedRunId != null) {
        tracker.untrackPid(pid);
      }
      await readerDone.future.timeout(drainTimeout, onTimeout: () {});
      receivePort.close();
      if (invocation.runId != null) {
        await sessionRegistry?.unregisterSession(sessionKey);
      }
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

String? _resolveExecutable(String executable, Map<String, String> env) {
  if (executable.contains('/')) {
    return File(executable).existsSync() ? executable : null;
  }
  final pathVar = env['PATH'] ?? Platform.environment['PATH'] ?? '';
  for (final dir in pathVar.split(':')) {
    if (dir.isEmpty) continue;
    final candidate = p.posix.join(dir, executable);
    final stat = File(candidate).statSync();
    if (stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0) {
      return candidate;
    }
  }
  return null;
}

Pointer<Pointer<Utf8>> _allocStringArray(List<String> items) {
  final ptr = calloc<Pointer<Utf8>>(items.length + 1);
  for (var i = 0; i < items.length; i++) {
    ptr[i] = items[i].toNativeUtf8();
  }
  ptr[items.length] = nullptr;
  return ptr;
}

void _freeStringArray(Pointer<Pointer<Utf8>> ptr) {
  var i = 0;
  while (ptr[i] != nullptr) {
    calloc.free(ptr[i]);
    i++;
  }
  calloc.free(ptr);
}
