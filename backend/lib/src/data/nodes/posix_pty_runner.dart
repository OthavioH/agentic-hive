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
const int _oCloexecLinux = 0x80000;
const int _oCloexecMacos = 0x1000000;
const int _posixSpawnSetsidLinux = 0x80;
const int _posixSpawnSetsidMacos = 0x0400;
const int _eintr = 4;
const int _echild = 10;
const int _fSetfd = 2;
const int _fdCloexec = 1;
const int _pollIn = 0x0001;
const int _pollErr = 0x0008;
const int _pollHup = 0x0010;
const int _pollNval = 0x0020;
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

final class _PollFd extends Struct {
  @Int32()
  external int fd;

  @Int16()
  external int events;

  @Int16()
  external int revents;
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
  UnsignedLong request,
  VarArgs<(Pointer<Void>,)>,
);
typedef _IoctlDart = int Function(int fd, int request, Pointer<Void> arg);

typedef _PipeNative = Int32 Function(Pointer<Int32> fds);
typedef _PipeDart = int Function(Pointer<Int32> fds);

typedef _FcntlNative = Int32 Function(Int32 fd, Int32 cmd, VarArgs<(Int32,)>);
typedef _FcntlDart = int Function(int fd, int cmd, int arg);

typedef _PollNative = Int32 Function(
  Pointer<_PollFd> fds,
  UintPtr nfds,
  Int32 timeout,
);
typedef _PollDart = int Function(Pointer<_PollFd> fds, int nfds, int timeout);

typedef _PosixSpawnNative = Int32 Function(
  Pointer<Int32> pid,
  Pointer<Utf8> path,
  Pointer<Void> fileActions,
  Pointer<Void> attrp,
  Pointer<Pointer<Utf8>> argv,
  Pointer<Pointer<Utf8>> envp,
);
typedef _PosixSpawnDart = int Function(
  Pointer<Int32> pid,
  Pointer<Utf8> path,
  Pointer<Void> fileActions,
  Pointer<Void> attrp,
  Pointer<Pointer<Utf8>> argv,
  Pointer<Pointer<Utf8>> envp,
);

typedef _PosixSpawnAttrInitNative = Int32 Function(Pointer<Void> attr);
typedef _PosixSpawnAttrInitDart = int Function(Pointer<Void> attr);

typedef _PosixSpawnAttrDestroyNative = Int32 Function(Pointer<Void> attr);
typedef _PosixSpawnAttrDestroyDart = int Function(Pointer<Void> attr);

typedef _PosixSpawnAttrSetFlagsNative = Int32 Function(
  Pointer<Void> attr,
  Int16 flags,
);
typedef _PosixSpawnAttrSetFlagsDart = int Function(
  Pointer<Void> attr,
  int flags,
);

typedef _PosixSpawnFileActionsInitNative = Int32 Function(
  Pointer<Void> fileActions,
);
typedef _PosixSpawnFileActionsInitDart = int Function(
  Pointer<Void> fileActions,
);

typedef _PosixSpawnFileActionsDestroyNative = Int32 Function(
  Pointer<Void> fileActions,
);
typedef _PosixSpawnFileActionsDestroyDart = int Function(
  Pointer<Void> fileActions,
);

typedef _PosixSpawnFileActionsAddOpenNative = Int32 Function(
  Pointer<Void> fileActions,
  Int32 fildes,
  Pointer<Utf8> path,
  Int32 oflag,
  Uint32 mode,
);
typedef _PosixSpawnFileActionsAddOpenDart = int Function(
  Pointer<Void> fileActions,
  int fildes,
  Pointer<Utf8> path,
  int oflag,
  int mode,
);

typedef _PosixSpawnFileActionsAddDup2Native = Int32 Function(
  Pointer<Void> fileActions,
  Int32 fildes,
  Int32 newfildes,
);
typedef _PosixSpawnFileActionsAddDup2Dart = int Function(
  Pointer<Void> fileActions,
  int fildes,
  int newfildes,
);

typedef _PosixSpawnFileActionsAddCloseNative = Int32 Function(
  Pointer<Void> fileActions,
  Int32 fildes,
);
typedef _PosixSpawnFileActionsAddCloseDart = int Function(
  Pointer<Void> fileActions,
  int fildes,
);

typedef _PosixSpawnFileActionsAddChdirNative = Int32 Function(
  Pointer<Void> fileActions,
  Pointer<Utf8> path,
);
typedef _PosixSpawnFileActionsAddChdirDart = int Function(
  Pointer<Void> fileActions,
  Pointer<Utf8> path,
);

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
    ioctl = lib.lookupFunction<_IoctlNative, _IoctlDart>('ioctl', isLeaf: true);
    pipe = lib.lookupFunction<_PipeNative, _PipeDart>('pipe', isLeaf: true);
    fcntl = lib.lookupFunction<_FcntlNative, _FcntlDart>('fcntl', isLeaf: true);
    poll = lib.lookupFunction<_PollNative, _PollDart>('poll');
    posixSpawn = lib.lookupFunction<_PosixSpawnNative, _PosixSpawnDart>(
      'posix_spawn',
    );
    posixSpawnAttrInit = lib
        .lookupFunction<_PosixSpawnAttrInitNative, _PosixSpawnAttrInitDart>(
          'posix_spawnattr_init',
          isLeaf: true,
        );
    posixSpawnAttrDestroy = lib
        .lookupFunction<
          _PosixSpawnAttrDestroyNative,
          _PosixSpawnAttrDestroyDart
        >('posix_spawnattr_destroy', isLeaf: true);
    posixSpawnAttrSetFlags = lib
        .lookupFunction<
          _PosixSpawnAttrSetFlagsNative,
          _PosixSpawnAttrSetFlagsDart
        >('posix_spawnattr_setflags', isLeaf: true);
    posixSpawnFileActionsInit = lib
        .lookupFunction<
          _PosixSpawnFileActionsInitNative,
          _PosixSpawnFileActionsInitDart
        >('posix_spawn_file_actions_init', isLeaf: true);
    posixSpawnFileActionsDestroy = lib
        .lookupFunction<
          _PosixSpawnFileActionsDestroyNative,
          _PosixSpawnFileActionsDestroyDart
        >('posix_spawn_file_actions_destroy', isLeaf: true);
    posixSpawnFileActionsAddOpen = lib
        .lookupFunction<
          _PosixSpawnFileActionsAddOpenNative,
          _PosixSpawnFileActionsAddOpenDart
        >('posix_spawn_file_actions_addopen', isLeaf: true);
    posixSpawnFileActionsAddDup2 = lib
        .lookupFunction<
          _PosixSpawnFileActionsAddDup2Native,
          _PosixSpawnFileActionsAddDup2Dart
        >('posix_spawn_file_actions_adddup2', isLeaf: true);
    posixSpawnFileActionsAddClose = lib
        .lookupFunction<
          _PosixSpawnFileActionsAddCloseNative,
          _PosixSpawnFileActionsAddCloseDart
        >('posix_spawn_file_actions_addclose', isLeaf: true);
    final addChdirSym =
        lib.providesSymbol('posix_spawn_file_actions_addchdir_np')
        ? 'posix_spawn_file_actions_addchdir_np'
        : 'posix_spawn_file_actions_addchdir';
    posixSpawnFileActionsAddChdir = lib
        .lookupFunction<
          _PosixSpawnFileActionsAddChdirNative,
          _PosixSpawnFileActionsAddChdirDart
        >(addChdirSym, isLeaf: true);
    waitpid = lib.lookupFunction<_WaitpidNative, _WaitpidDart>('waitpid');
    kill = lib.lookupFunction<_KillNative, _KillDart>('kill', isLeaf: true);
    _errnoPtr = lib.lookupFunction<_ErrnoPtrNative, _ErrnoPtrDart>(
      errnoSymbol,
      isLeaf: true,
    );
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
  late final _PipeDart pipe;
  late final _FcntlDart fcntl;
  late final _PollDart poll;
  late final _PosixSpawnDart posixSpawn;
  late final _PosixSpawnAttrInitDart posixSpawnAttrInit;
  late final _PosixSpawnAttrDestroyDart posixSpawnAttrDestroy;
  late final _PosixSpawnAttrSetFlagsDart posixSpawnAttrSetFlags;
  late final _PosixSpawnFileActionsInitDart posixSpawnFileActionsInit;
  late final _PosixSpawnFileActionsDestroyDart posixSpawnFileActionsDestroy;
  late final _PosixSpawnFileActionsAddOpenDart posixSpawnFileActionsAddOpen;
  late final _PosixSpawnFileActionsAddDup2Dart posixSpawnFileActionsAddDup2;
  late final _PosixSpawnFileActionsAddCloseDart posixSpawnFileActionsAddClose;
  late final _PosixSpawnFileActionsAddChdirDart posixSpawnFileActionsAddChdir;
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
    required this.oCloexec,
    required this.posixSpawnSetsid,
    required this.tiocswinsz,
    required this.tiocsctty,
    required this.errnoSymbol,
  });

  /// Linux PTY constants.
  static const PosixPtyConfig linux = PosixPtyConfig(
    oNoctty: _oNocttyLinux,
    oCloexec: _oCloexecLinux,
    posixSpawnSetsid: _posixSpawnSetsidLinux,
    tiocswinsz: _tiocswinszLinux,
    tiocsctty: _tiocscttyLinux,
    errnoSymbol: '__errno_location',
  );

  /// macOS PTY constants.
  static const PosixPtyConfig macos = PosixPtyConfig(
    oNoctty: _oNocttyMacos,
    oCloexec: _oCloexecMacos,
    posixSpawnSetsid: _posixSpawnSetsidMacos,
    tiocswinsz: _tiocswinszMacos,
    tiocsctty: _tiocscttyMacos,
    errnoSymbol: '__error',
  );

  /// `O_NOCTTY` open flag.
  final int oNoctty;

  /// `O_CLOEXEC` open flag.
  final int oCloexec;

  /// `POSIX_SPAWN_SETSID` spawn attribute flag.
  final int posixSpawnSetsid;

  /// `TIOCSWINSZ` ioctl request.
  final int tiocswinsz;

  /// `TIOCSCTTY` ioctl request.
  final int tiocsctty;

  /// C runtime errno lookup symbol (`__errno_location` or `__error`).
  final String errnoSymbol;
}

void _posixReaderIsolate(
  ({int fd, int stopFd, String errnoSymbol, SendPort port}) args,
) {
  final libc = _PosixLibc._(args.errnoSymbol);
  const bufSize = 4096;
  final buf = calloc<Uint8>(bufSize);
  final fds = calloc<_PollFd>(2);
  try {
    while (true) {
      fds[0]
        ..fd = args.fd
        ..events = _pollIn
        ..revents = 0;
      fds[1]
        ..fd = args.stopFd
        ..events = _pollIn
        ..revents = 0;
      final ready = libc.poll(fds, 2, -1);
      if (ready < 0) {
        if (libc.errno == _eintr) continue;
        break;
      }
      if ((fds[0].revents & _pollIn) != 0) {
        final n = libc.read(args.fd, buf, bufSize);
        if (n > 0) {
          args.port.send(Uint8List.fromList(buf.asTypedList(n)));
          continue;
        } else if (n == 0) {
          break;
        } else if (libc.errno != _eintr) {
          break;
        }
      }
      if ((fds[1].revents & (_pollIn | _pollHup | _pollErr | _pollNval)) != 0) {
        break;
      }
      if ((fds[0].revents & (_pollHup | _pollErr | _pollNval)) != 0) {
        break;
      }
    }
  } finally {
    calloc
      ..free(buf)
      ..free(fds);
    args.port.send(null);
  }
}

void _posixWriterIsolate(({int fd, String errnoSymbol, SendPort port}) args) {
  final libc = _PosixLibc._(args.errnoSymbol);
  final rx = ReceivePort();
  args.port.send(rx.sendPort);
  const chunkSize = 4096;
  final buf = calloc<Uint8>(chunkSize);
  void cleanup() {
    calloc.free(buf);
    args.port.send(null);
  }

  rx.listen((message) {
    if (message == null) {
      rx.close();
      return;
    }
    final bytes = message as Uint8List;
    var offset = 0;
    while (offset < bytes.length) {
      final len = (bytes.length - offset) > chunkSize
          ? chunkSize
          : (bytes.length - offset);
      buf.asTypedList(len).setRange(0, len, bytes, offset);
      var chunkOffset = 0;
      while (chunkOffset < len) {
        final written = libc.write(
          args.fd,
          buf + chunkOffset,
          len - chunkOffset,
        );
        if (written <= 0) {
          if (written == -1 && libc.errno == _eintr) continue;
          rx.close();
          return;
        }
        chunkOffset += written;
      }
      offset += len;
    }
  }, onDone: cleanup);
}

int _readExitCodeFromPipe(_PosixLibc libc, int fd) {
  final buf = calloc<Uint8>(64);
  final bytes = <int>[];
  try {
    while (true) {
      final n = libc.read(fd, buf, 64);
      if (n > 0) {
        bytes.addAll(buf.asTypedList(n));
        continue;
      }
      if (n == 0) {
        break;
      }
      if (libc.errno == _eintr) {
        continue;
      }
      return -1;
    }
  } finally {
    calloc.free(buf);
  }
  if (bytes.isEmpty) {
    return -1;
  }
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  return int.tryParse(text) ?? -1;
}

int _waitpidIsolate(({int pid, int exitReadFd, String errnoSymbol}) args) {
  final libc = _PosixLibc._(args.errnoSymbol);
  final statusPtr = calloc<Int32>();
  try {
    while (true) {
      final waited = libc.waitpid(args.pid, statusPtr, 0);
      if (waited == -1) {
        final err = libc.errno;
        if (err == _eintr) continue;
        if (err == _echild) {
          return _readExitCodeFromPipe(libc, args.exitReadFd);
        }
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
    libc.close(args.exitReadFd);
    calloc.free(statusPtr);
  }
}

Future<int> _waitpidAsync(int pid, int exitReadFd, String errnoSymbol) =>
    Isolate.run(
      () => _waitpidIsolate((
        pid: pid,
        exitReadFd: exitReadFd,
        errnoSymbol: errnoSymbol,
      )),
    );

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
  SendPort? _writerSendPort;
  Completer<void>? _writerDone;

  @override
  bool get isActive => _active;

  void attachWriter(SendPort sendPort, Completer<void> done) {
    _writerSendPort = sendPort;
    _writerDone = done;
  }

  void markClosed() {
    _active = false;
  }

  Future<void> closeWriter() async {
    final writerPort = _writerSendPort;
    if (writerPort != null) {
      _writerSendPort = null;
      writerPort.send(null);
      await _writerDone?.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    }
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
    final writerPort = _writerSendPort;
    if (writerPort != null) {
      writerPort.send(Uint8List.fromList(bytes));
    }
  }

  @override
  Future<void> resize(int cols, int rows) async {
    if (!_active || _masterFd < 0 || cols <= 0 || rows <= 0) return;
    final winSize = calloc<_WinSize>();
    try {
      winSize.ref
        ..wsCol = cols.clamp(1, 65535)
        ..wsRow = rows.clamp(1, 65535)
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

/// POSIX (`posix_openpt` + `posix_spawn`) implementation of [PtyRunner] for
/// Linux and macOS using `dart:ffi`.
final class PosixPtyRunner implements PtyRunner {
  /// Creates a POSIX PTY runner.
  const new({
    required this.config,
    this.processTracker,
    this.processTreeKiller,
    this.sessionRegistry,
    this.maxOutputLength = defaultMaxOutputLength,
    this.drainTimeout = defaultDrainTimeout,
    this.initialInputDelay = defaultInitialInputDelay,
  });

  /// Default retained stdout cap (1 MiB of characters).
  static const int defaultMaxOutputLength = 1024 * 1024;

  /// Default maximum time to wait for PTY output drain after exit.
  static const Duration defaultDrainTimeout = Duration(seconds: 2);

  /// Default brief startup delay before writing [PtyInvocation.initialInput]
  /// so the child terminal/TUI has initialized its input mode.
  static const Duration defaultInitialInputDelay = Duration(milliseconds: 150);

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

  /// Delay before sending [PtyInvocation.initialInput] after process spawn.
  final Duration initialInputDelay;

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
    final masterFd = libc.posixOpenpt(
      _oRdwr | config.oNoctty | config.oCloexec,
    );
    if (masterFd < 0) {
      return FailureResult(
        NodeExecutionFailure('posix_openpt failed (errno ${libc.errno}).'),
      );
    }

    final stopPipeFds = calloc<Int32>(2);
    var stopReadFd = -1;
    var stopWriteFd = -1;
    final exitPipeFds = calloc<Int32>(2);
    var exitReadFd = -1;
    var exitWriteFd = -1;
    var pid = -1;

    final pidPtr = calloc<Int32>();
    final winSize = calloc<_WinSize>();
    final spawnAttr = calloc<Uint8>(512).cast<Void>();
    final fileActions = calloc<Uint8>(256).cast<Void>();
    var attrInitialized = false;
    var actionsInitialized = false;

    final argv = _allocStringArray(<String>[
      '/bin/sh',
      '-c',
      r'"$@" 3>&-; c=$?; printf "%d" "$c" >&3; exit "$c"',
      'agentic-hive-pty',
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
    final execPtr = '/bin/sh'.toNativeUtf8();
    final cwdPtr = invocation.workingDirectory.toNativeUtf8();

    try {
      if (libc.pipe(stopPipeFds) != 0) {
        return FailureResult(
          NodeExecutionFailure('pipe() failed (errno ${libc.errno}).'),
        );
      }
      stopReadFd = stopPipeFds[0];
      stopWriteFd = stopPipeFds[1];
      libc
        ..fcntl(stopReadFd, _fSetfd, _fdCloexec)
        ..fcntl(stopWriteFd, _fSetfd, _fdCloexec);

      if (libc.pipe(exitPipeFds) != 0) {
        return FailureResult(
          NodeExecutionFailure('pipe() failed (errno ${libc.errno}).'),
        );
      }
      exitReadFd = exitPipeFds[0];
      exitWriteFd = exitPipeFds[1];
      libc
        ..fcntl(exitReadFd, _fSetfd, _fdCloexec)
        ..fcntl(exitWriteFd, _fSetfd, _fdCloexec);

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

      winSize.ref
        ..wsCol = invocation.cols.clamp(1, 65535)
        ..wsRow = invocation.rows.clamp(1, 65535)
        ..wsXpixel = 0
        ..wsYpixel = 0;
      libc.ioctl(masterFd, config.tiocswinsz, winSize.cast<Void>());

      final attrInitErr = libc.posixSpawnAttrInit(spawnAttr);
      if (attrInitErr != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'posix_spawnattr_init failed (errno $attrInitErr).',
          ),
        );
      }
      attrInitialized = true;

      final setFlagsErr = libc.posixSpawnAttrSetFlags(
        spawnAttr,
        config.posixSpawnSetsid,
      );
      if (setFlagsErr != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'posix_spawnattr_setflags(POSIX_SPAWN_SETSID) failed '
            '(errno $setFlagsErr).',
          ),
        );
      }

      final actionsInitErr = libc.posixSpawnFileActionsInit(fileActions);
      if (actionsInitErr != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'posix_spawn_file_actions_init failed (errno $actionsInitErr).',
          ),
        );
      }
      actionsInitialized = true;

      // Open the slave PTY on fd 0 without O_NOCTTY so the new session leader
      // acquires it as its controlling terminal, then dup2 to stdout/stderr.
      final addOpenErr = libc.posixSpawnFileActionsAddOpen(
        fileActions,
        0,
        slaveNamePtr,
        _oRdwr,
        0,
      );
      if (addOpenErr != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'posix_spawn_file_actions_addopen failed (errno $addOpenErr).',
          ),
        );
      }
      final addDup1Err = libc.posixSpawnFileActionsAddDup2(fileActions, 0, 1);
      final addDup2Err = libc.posixSpawnFileActionsAddDup2(fileActions, 0, 2);
      final addDup3Err = libc.posixSpawnFileActionsAddDup2(
        fileActions,
        exitWriteFd,
        3,
      );
      final addCloseExitWriteErr = exitWriteFd != 3
          ? libc.posixSpawnFileActionsAddClose(fileActions, exitWriteFd)
          : 0;
      final addChdirErr = libc.posixSpawnFileActionsAddChdir(
        fileActions,
        cwdPtr,
      );
      if (addDup1Err != 0 ||
          addDup2Err != 0 ||
          addDup3Err != 0 ||
          addCloseExitWriteErr != 0 ||
          addChdirErr != 0) {
        return FailureResult(
          NodeExecutionFailure(
            'posix_spawn_file_actions setup failed '
            '($addDup1Err, $addDup2Err, $addDup3Err, '
            '$addCloseExitWriteErr, $addChdirErr).',
          ),
        );
      }

      final spawnErr = libc.posixSpawn(
        pidPtr,
        execPtr,
        fileActions,
        spawnAttr,
        argv,
        envp,
      );
      if (spawnErr != 0) {
        return FailureResult(
          NodeExecutionFailure('posix_spawn failed (errno $spawnErr).'),
        );
      }
      pid = pidPtr.value;
      libc.close(exitWriteFd);
      exitWriteFd = -1;
    } finally {
      if (actionsInitialized) {
        libc.posixSpawnFileActionsDestroy(fileActions);
      }
      if (attrInitialized) {
        libc.posixSpawnAttrDestroy(spawnAttr);
      }
      _freeStringArray(argv);
      _freeStringArray(envp);
      calloc
        ..free(stopPipeFds)
        ..free(exitPipeFds)
        ..free(pidPtr)
        ..free(winSize)
        ..free(spawnAttr)
        ..free(fileActions)
        ..free(execPtr)
        ..free(cwdPtr);

      if (pid <= 0) {
        if (stopReadFd >= 0) libc.close(stopReadFd);
        if (stopWriteFd >= 0) libc.close(stopWriteFd);
        if (exitReadFd >= 0) libc.close(exitReadFd);
        if (exitWriteFd >= 0) libc.close(exitWriteFd);
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
    final writerPort = ReceivePort();
    final readerDone = Completer<void>();
    final writerReady = Completer<SendPort>();
    final writerDone = Completer<void>();
    final stdoutBuffer = StringBuffer();
    final lineBuffer = StringBuffer();
    var truncated = false;
    final utf8InputSink = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(
          _CallbackStringSink((text) {
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
          }),
        );

    receivePort.listen((message) {
      if (message == null) {
        if (!readerDone.isCompleted) readerDone.complete();
        return;
      }
      final bytes = message as Uint8List;
      if (invocation.runId != null) {
        sessionRegistry?.appendOutput(sessionKey, bytes);
      }
      utf8InputSink.add(bytes);
    });

    writerPort.listen((message) {
      if (message is SendPort && !writerReady.isCompleted) {
        writerReady.complete(message);
      } else if (message == null && !writerDone.isCompleted) {
        writerDone.complete();
      }
    });

    var readerSpawned = false;
    var writerAttached = false;
    var timedOut = false;
    var waitTimedOutAfterKill = false;
    var exitCode = -1;
    var exitReadFdOwnedByWaiter = false;

    try {
      await Isolate.spawn(_posixReaderIsolate, (
        fd: masterFd,
        stopFd: stopReadFd,
        errnoSymbol: config.errnoSymbol,
        port: receivePort.sendPort,
      ), errorsAreFatal: false);
      readerSpawned = true;

      await Isolate.spawn(_posixWriterIsolate, (
        fd: masterFd,
        errnoSymbol: config.errnoSymbol,
        port: writerPort.sendPort,
      ), errorsAreFatal: false);
      final writerSendPort = await writerReady.future;
      handle.attachWriter(writerSendPort, writerDone);
      writerAttached = true;

      if (invocation.initialInput case final input? when input.isNotEmpty) {
        if (initialInputDelay > Duration.zero) {
          await Future<void>.delayed(initialInputDelay);
        }
        if (handle.isActive) {
          await handle.writeInput(utf8.encode(input));
        }
      }

      exitReadFdOwnedByWaiter = true;
      final waitFuture = _waitpidAsync(pid, exitReadFd, config.errnoSymbol);
      final timeout = invocation.timeout;
      if (timeout != null) {
        exitCode = await waitFuture.timeout(
          timeout,
          onTimeout: () async {
            timedOut = true;
            await terminateProcessTree();
            final drained = await waitFuture
                .then<int?>((code) => code)
                .timeout(drainTimeout, onTimeout: () => null);
            if (drained == null) {
              waitTimedOutAfterKill = true;
              return -1;
            }
            return drained;
          },
        );
      } else {
        exitCode = await waitFuture;
      }
    } finally {
      if (!exitReadFdOwnedByWaiter && exitReadFd >= 0) {
        libc.close(exitReadFd);
      }
      if (!writerAttached) {
        await terminateProcessTree();
      }
      if (!exitCompleter.isCompleted) {
        exitCompleter.complete(exitCode);
      }
      handle.markClosed();
      await handle.closeWriter();
      if (tracker != null && trackedRunId != null) {
        tracker.untrackPid(pid);
      }
      if (readerSpawned) {
        await readerDone.future.timeout(drainTimeout, onTimeout: () {});
        if (!readerDone.isCompleted && stopWriteFd >= 0) {
          libc.close(stopWriteFd);
          stopWriteFd = -1;
          await readerDone.future.timeout(
            const Duration(milliseconds: 200),
            onTimeout: () {},
          );
        }
      }
      if (stopWriteFd >= 0) libc.close(stopWriteFd);
      if (stopReadFd >= 0) libc.close(stopReadFd);
      handle.closeMasterFd();
      receivePort.close();
      writerPort.close();
      utf8InputSink.close();
      if (invocation.runId != null) {
        await sessionRegistry?.unregisterSession(sessionKey);
      }
    }

    if (lineBuffer.isNotEmpty) {
      onOutput?.call('stdout', lineBuffer.toString());
    }

    if (waitTimedOutAfterKill) {
      return FailureResult(
        NodeExecutionFailure(
          'Process "${invocation.executable}" did not exit within '
          '$drainTimeout after timeout and termination.',
        ),
      );
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

final class _CallbackStringSink implements Sink<String> {
  const new(this._onData);

  final void Function(String) _onData;

  @override
  void add(String data) => _onData(data);

  @override
  void close() {}
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
