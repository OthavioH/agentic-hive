import 'dart:async';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_mark_store.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

/// Installs the skill and the MCP the first time each harness is detected
/// (ADR 0028) and keeps the notice data until the user dismisses it.
abstract interface class SkillAutoInstallService {
  /// Emits the full pending notice every time results are added.
  Stream<SkillAutoInstallNotice> get notices;

  /// The pending notice, or `null`.
  SkillAutoInstallNotice? get pendingNotice;

  /// Whether [start] ran.
  bool get isStarted;

  /// Subscribes to detections and setting changes and triggers the first scan.
  /// Idempotent. Without this call the service never installs anything.
  void start();

  /// Clears the pending notice (the user dismissed it).
  ///
  /// When [noticeId] is provided, only clears if it matches the currently
  /// pending notice's id so dismissing a stale notice does not drop newer
  /// results.
  void dismissNotice({String? noticeId});

  /// Waits until every queued detection was processed.
  Future<void> idle();

  /// Releases subscriptions and stream resources.
  Future<void> dispose();
}

/// Default implementation of [SkillAutoInstallService].
final class DefaultSkillAutoInstallService implements SkillAutoInstallService {
  /// Creates a [DefaultSkillAutoInstallService].
  new({
    required this._harnessService,
    required this._settingsService,
    required this._markStore,
    required this._skillInstallers,
    this._mcpInstallers,
    DateTime Function()? now,
    String Function()? generateId,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _generateId = generateId ?? randomId;

  static final _log = Logger('skills.auto_install');

  final HarnessService _harnessService;
  final SettingsService _settingsService;
  final SkillAutoInstallMarkStore _markStore;
  final HarnessSkillInstallerRegistry _skillInstallers;
  final HarnessMcpInstallerRegistry? _mcpInstallers;
  final DateTime Function() _now;
  final String Function() _generateId;

  final StreamController<SkillAutoInstallNotice> _controller =
      StreamController<SkillAutoInstallNotice>.broadcast();

  Future<void> _queue = Future<void>.value();
  Future<void>? _pendingScan;
  SkillAutoInstallNotice? _pending;
  StreamSubscription<HarnessInfo>? _detectionSub;
  StreamSubscription<AppSettings>? _settingsSub;
  bool? _lastAutoInstallEnabled;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<SkillAutoInstallNotice> get notices => _controller.stream;

  @override
  SkillAutoInstallNotice? get pendingNotice => _pending;

  @override
  bool get isStarted => _started;

  @override
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _detectionSub = _harnessService.detections.listen(_enqueue);
    _settingsSub = _settingsService.settingsUpdates.listen(_onSettingsUpdated);
    _pendingScan = _initialScan();
    unawaited(_pendingScan);
  }

  Future<void> _initialScan() async {
    try {
      final settings = await _settingsService.getSettings();
      if (settings case FailureResult(:final failure)) {
        _log.warning(
          LogEvent(
            'skills.auto_install.start_failed',
            fields: {'failure': '${failure.runtimeType}'},
            userContent: failure.message,
          ),
        );
        return;
      }
      final enabled =
          (settings as Success<AppSettings>).value.autoInstallSkills;
      _lastAutoInstallEnabled = enabled;
      if (!enabled) return;

      await _evaluateAllCached();
    } on Object catch (error, stackTrace) {
      _log.warning(
        const LogEvent('skills.auto_install.start_failed'),
        error,
        stackTrace,
      );
    }
  }

  void _onSettingsUpdated(AppSettings settings) {
    final was = _lastAutoInstallEnabled;
    _lastAutoInstallEnabled = settings.autoInstallSkills;
    if (settings.autoInstallSkills && was != true) {
      _pendingScan = _evaluateAllCached();
      unawaited(_pendingScan);
    }
  }

  Future<void> _evaluateAllCached() async {
    try {
      final list = await _harnessService.listHarnesses();
      (list.valueOrNull ?? const <HarnessInfo>[]).forEach(_enqueue);
    } on Object catch (error, stackTrace) {
      _log.warning(
        const LogEvent('skills.auto_install.evaluate_failed'),
        error,
        stackTrace,
      );
    }
  }

  void _enqueue(HarnessInfo info) {
    if (_disposed) return;
    _queue = _queue.then((_) => _process(info.id)).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _log.warning(
        const LogEvent('skills.auto_install.queue_error'),
        error,
        stackTrace,
      );
    });
  }

  Future<void> _process(HarnessId id) async {
    if (_disposed) return;

    final settings = await _settingsService.getSettings();
    if (settings case FailureResult(:final failure)) {
      _log.warning(
        LogEvent(
          'skills.auto_install.settings_failed',
          fields: {'failure': '${failure.runtimeType}'},
          userContent: failure.message,
        ),
      );
      return;
    }
    if (!(settings as Success<AppSettings>).value.autoInstallSkills) {
      return;
    }

    final info = _harnessService.cachedInfo(id);
    if (info == null ||
        info.status == HarnessStatus.notInstalled ||
        info.executablePath == null) {
      return;
    }

    if (await _markStore.isMarked(id)) {
      return;
    }

    try {
      await _markStore.mark(id);
    } on Object catch (error, stackTrace) {
      _log.warning(
        LogEvent(
          'skills.auto_install.mark_failed',
          fields: {'harness': id.wireName},
        ),
        error,
        stackTrace,
      );
      return;
    }

    final skillStep = await _runStep(() => _skillStep(id));
    final mcpStep = await _runStep(() => _mcpStep(id));

    final result = SkillAutoInstallHarnessResult(
      harnessId: id,
      skill: skillStep,
      mcp: mcpStep,
    );

    _log.info(
      LogEvent(
        'skills.auto_install.processed',
        fields: {
          'harness': id.wireName,
          'skill': skillStep.outcome.name,
          'mcp': mcpStep.outcome.name,
        },
      ),
    );

    if (_isNotifiable(skillStep.outcome) || _isNotifiable(mcpStep.outcome)) {
      _addToNotice(result);
    }
  }

  static bool _isNotifiable(SkillAutoInstallOutcome outcome) =>
      outcome == SkillAutoInstallOutcome.installed ||
      outcome == SkillAutoInstallOutcome.failed;

  Future<SkillAutoInstallStep> _runStep(
    Future<SkillAutoInstallStep> Function() action,
  ) async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      _log.warning(
        const LogEvent('skills.auto_install.step_exception'),
        error,
        stackTrace,
      );
      return const SkillAutoInstallStep(
        outcome: SkillAutoInstallOutcome.failed,
        message: 'Unexpected error while installing.',
      );
    }
  }

  Future<SkillAutoInstallStep> _skillStep(HarnessId id) async {
    final info = _harnessService.cachedInfo(id);
    final status = info?.skillStatus;
    if (status == null) {
      return SkillAutoInstallStep(
        outcome: SkillAutoInstallOutcome.skipped,
        message: 'Skill installation is not supported for ${id.displayName}.',
      );
    }

    switch (status) {
      case HarnessSkillStatus.installed:
        return const SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.alreadyInstalled,
        );
      case HarnessSkillStatus.notInstalled:
        final result = await _harnessService.installSkill(id);
        switch (result) {
          case FailureResult(:final failure):
            return SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.failed,
              message: failure.message,
            );
          case Success():
            final dir = _skillInstallers[id]?.skillDirectory;
            return SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
              paths: dir == null ? const <String>[] : <String>[dir],
            );
        }
      case HarnessSkillStatus.outdated:
        return const SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.skipped,
          message:
              'The installed skill is outdated. Update it from the Harnesses '
              'page.',
        );
      case HarnessSkillStatus.modified:
        return const SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.skipped,
          message:
              'The installed skill was edited by hand and was left untouched.',
        );
      case HarnessSkillStatus.conflict:
      case HarnessSkillStatus.unknown:
        return SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.skipped,
          message: info?.skillMessage ?? 'The skill was left untouched.',
        );
    }
  }

  Future<SkillAutoInstallStep> _mcpStep(HarnessId id) async {
    final info = _harnessService.cachedInfo(id);
    final status = info?.mcpStatus;
    if (status == null) {
      return SkillAutoInstallStep(
        outcome: SkillAutoInstallOutcome.skipped,
        message: info?.mcpMessage ?? 'The Hive MCP server was left untouched.',
      );
    }

    switch (status) {
      case HarnessMcpStatus.installed:
        return const SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.alreadyInstalled,
        );
      case HarnessMcpStatus.notInstalled:
        final result = await _harnessService.installMcp(id);
        switch (result) {
          case FailureResult(:final failure):
            return SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.failed,
              message: failure.message,
            );
          case Success():
            final configPath = _mcpInstallers?[id]?.configPath;
            return SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
              paths: configPath == null
                  ? const <String>[]
                  : <String>[configPath],
            );
        }
      case HarnessMcpStatus.outdated:
        return const SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.skipped,
          message:
              'The Hive MCP server entry is outdated. Update it from the '
              'Harnesses page.',
        );
      case HarnessMcpStatus.unsupported:
      case HarnessMcpStatus.unknown:
        return SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.skipped,
          message:
              info?.mcpMessage ?? 'The Hive MCP server was left untouched.',
        );
    }
  }

  void _addToNotice(SkillAutoInstallHarnessResult result) {
    final existing =
        _pending?.results ?? const <SkillAutoInstallHarnessResult>[];
    final updatedResults = <SkillAutoInstallHarnessResult>[
      for (final item in existing)
        if (item.harnessId != result.harnessId) item,
      result,
    ];
    final notice = SkillAutoInstallNotice(
      id: _generateId(),
      createdAt: _now().toUtc(),
      results: updatedResults,
    );
    _pending = notice;
    if (!_controller.isClosed) {
      _controller.add(notice);
    }
  }

  @override
  void dismissNotice({String? noticeId}) {
    if (noticeId == null || _pending?.id == noticeId) {
      _pending = null;
    }
  }

  @override
  Future<void> idle() async {
    await Future<void>.delayed(Duration.zero);
    await _pendingScan;
    await _queue;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _detectionSub?.cancel();
    await _settingsSub?.cancel();
    await _queue;
    await _controller.close();
  }
}
