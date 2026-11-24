import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_controller.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/settings/controllers/settings_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Desktop Settings page for configuring appearance, default paths, and
/// custom harness executable overrides.
class SettingsPage extends ConsumerWidget {
  /// Creates a [SettingsPage].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final asyncState = ref.watch(settingsControllerProvider);
    final currentState = asyncState.value;
    final canAct =
        currentState != null &&
        currentState.hasUnsavedChanges &&
        !currentState.isSaving;
    final isSaving = currentState?.isSaving ?? false;

    return Padding(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivePageHeader(
            title: l10n.navSettings,
            subtitle: l10n.settingsPageSubtitle,
            actions: <Widget>[
              HiveButton(
                key: const ValueKey<String>('settings_discard_button'),
                label: l10n.settingsDiscard,
                variant: HiveButtonVariant.secondary,
                onPressed: canAct
                    ? () => ref
                          .read(settingsControllerProvider.notifier)
                          .discard()
                    : null,
              ),
              HiveButton(
                key: const ValueKey<String>('settings_save_button'),
                label: l10n.settingsSave,
                loading: isSaving,
                onPressed: canAct ? () => _save(context, ref, l10n) : null,
              ),
            ],
          ),
          Expanded(
            child: switch (asyncState) {
              AsyncLoading<SettingsState>() => Center(
                child: HiveConnectionIndicator(
                  state: HiveConnectionState.connecting,
                  label: l10n.settingsLoading,
                ),
              ),
              AsyncError<SettingsState>(:final error) => HiveEmptyState(
                icon: HiveIcons.alert,
                title: l10n.settingsLoadErrorTitle,
                message: _localizedErrorMessage(error, l10n),
                action: HiveButton(
                  key: const ValueKey<String>('settings_retry_button'),
                  label: l10n.settingsRetry,
                  icon: HiveIcons.refresh,
                  onPressed: () => ref.invalidate(settingsControllerProvider),
                ),
              ),
              AsyncData<SettingsState>(:final value) => _SettingsForm(
                state: value,
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final result = await ref.read(settingsControllerProvider.notifier).save();
    if (!context.mounted) return;
    switch (result) {
      case Success<void>():
        HiveToast.show(
          context,
          message: l10n.settingsSavedToast,
          tone: HiveToastTone.success,
        );
      case FailureResult<void>(:final failure)
          when failure is! ValidationFailure:
        HiveToast.show(
          context,
          message: l10n.settingsSaveError(
            _localizedErrorMessage(failure, l10n),
          ),
          tone: HiveToastTone.danger,
        );
      case FailureResult<void>():
        // ValidationFailure populates inline per-field errors.
        break;
    }
  }

  String _localizedErrorMessage(Object error, AppLocalizations l10n) =>
      switch (error) {
        NetworkFailure() => l10n.settingsErrorNetwork,
        BackendFailure() => l10n.settingsErrorBackend,
        ValidationFailure(:final message) => message,
        NotFoundFailure() ||
        UnexpectedFailure() ||
        _ => l10n.settingsErrorUnexpected,
      };
}

class _SettingsForm extends ConsumerStatefulWidget {
  const new({required this.state});

  final SettingsState state;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final TextEditingController _agentsDirController;
  late final Map<HarnessId, TextEditingController> _harnessControllers;

  @override
  void initState() {
    super.initState();
    _agentsDirController = TextEditingController(
      text: widget.state.agentsDirDraft,
    );
    _harnessControllers = <HarnessId, TextEditingController>{
      for (final id in HarnessId.values)
        id: TextEditingController(
          text: widget.state.harnessOverridesDraft[id] ?? '',
        ),
    };
  }

  @override
  void didUpdateWidget(covariant _SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_agentsDirController, widget.state.agentsDirDraft);
    for (final id in HarnessId.values) {
      _syncController(
        _harnessControllers[id]!,
        widget.state.harnessOverridesDraft[id] ?? '',
      );
    }
  }

  void _syncController(TextEditingController controller, String target) {
    if (controller.text == target) return;
    controller.value = TextEditingValue(
      text: target,
      selection: TextSelection.collapsed(offset: target.length),
    );
  }

  @override
  void dispose() {
    _agentsDirController.dispose();
    for (final controller in _harnessControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final themePreference = ref.watch(themePreferenceControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final state = widget.state;

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.space8 * 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _AppearanceSection(
                themePreference: themePreference,
                onThemeChanged: (pref) => unawaited(
                  ref
                      .read(themePreferenceControllerProvider.notifier)
                      .setPreference(pref),
                ),
              ),
              SizedBox(height: spacing.space3),
              _PathsSection(
                state: state,
                agentsDirController: _agentsDirController,
                onAgentsDirChanged: controller.setAgentsDir,
                onBrowseAgentsDir: () =>
                    unawaited(controller.browseAgentsDir()),
                onResetAgentsDir: controller.resetAgentsDirToDefault,
              ),
              SizedBox(height: spacing.space3),
              _HarnessesSection(
                state: state,
                harnesses: HarnessId.values,
                controllers: _harnessControllers,
                onOverrideChanged: controller.setHarnessOverride,
                onBrowseOverride: (id) =>
                    unawaited(controller.browseHarnessExecutable(id)),
                onClearOverride: controller.clearHarnessOverride,
                l10n: l10n,
              ),
              SizedBox(height: spacing.space3),
              _SkillsSection(
                state: state,
                onAutoInstallSkillsChanged: controller.setAutoInstallSkills,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: typography.titleSmall.copyWith(color: colors.onSurface),
        ),
        SizedBox(height: spacing.spaceHalf),
        Text(
          description,
          style: typography.bodySmall.copyWith(color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const new({required this.themePreference, required this.onThemeChanged});

  final AppThemePreference themePreference;
  final ValueChanged<AppThemePreference> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    return HiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            title: l10n.settingsSectionAppearance,
            description: l10n.settingsSectionAppearanceDescription,
          ),
          SizedBox(height: spacing.space2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.settingsThemeLabel,
                  style: typography.body.copyWith(color: colors.onSurface),
                ),
              ),
              HiveSegmentedControl<AppThemePreference>(
                key: const ValueKey<String>('settings_theme_segmented_control'),
                semanticLabel: l10n.settingsThemeLabel,
                selected: themePreference,
                onChanged: onThemeChanged,
                segments: <HiveSegment<AppThemePreference>>[
                  HiveSegment<AppThemePreference>(
                    value: AppThemePreference.dark,
                    label: l10n.settingsThemeDark,
                  ),
                  HiveSegment<AppThemePreference>(
                    value: AppThemePreference.light,
                    label: l10n.settingsThemeLight,
                  ),
                  HiveSegment<AppThemePreference>(
                    value: AppThemePreference.system,
                    label: l10n.settingsThemeSystem,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PathsSection extends StatelessWidget {
  const new({
    required this.state,
    required this.agentsDirController,
    required this.onAgentsDirChanged,
    required this.onBrowseAgentsDir,
    required this.onResetAgentsDir,
  });

  final SettingsState state;
  final TextEditingController agentsDirController;
  final ValueChanged<String> onAgentsDirChanged;
  final VoidCallback onBrowseAgentsDir;
  final VoidCallback onResetAgentsDir;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final enabled = !state.isSaving;
    final canResetAgents =
        enabled && state.agentsDirDraft.trim() != state.saved.defaultAgentsDir;

    return HiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionHeader(
            title: l10n.settingsSectionPaths,
            description: l10n.settingsSectionPathsDescription,
          ),
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const ValueKey<String>('settings_agents_dir_field'),
            label: l10n.settingsAgentsFolderLabel,
            controller: agentsDirController,
            hintText: l10n.settingsAgentsFolderHint,
            helperText: l10n.settingsAgentsFolderHelper(
              state.saved.defaultAgentsDir,
            ),
            errorText: state.fieldErrors['agentsDir'],
            enabled: enabled,
            onChanged: onAgentsDirChanged,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HiveButton(
                  key: const ValueKey<String>(
                    'settings_agents_dir_browse_button',
                  ),
                  label: l10n.settingsBrowse,
                  icon: HiveIcons.folder,
                  variant: HiveButtonVariant.ghost,
                  size: HiveButtonSize.small,
                  onPressed: enabled ? onBrowseAgentsDir : null,
                ),
                SizedBox(width: spacing.space1),
                HiveButton(
                  key: const ValueKey<String>(
                    'settings_agents_dir_reset_button',
                  ),
                  label: l10n.settingsResetToDefault,
                  variant: HiveButtonVariant.ghost,
                  size: HiveButtonSize.small,
                  onPressed: canResetAgents ? onResetAgentsDir : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HarnessesSection extends StatelessWidget {
  const new({
    required this.state,
    required this.harnesses,
    required this.controllers,
    required this.onOverrideChanged,
    required this.onBrowseOverride,
    required this.onClearOverride,
    required this.l10n,
  });

  final SettingsState state;
  final List<HarnessId> harnesses;
  final Map<HarnessId, TextEditingController> controllers;
  final void Function(HarnessId id, String value) onOverrideChanged;
  final ValueChanged<HarnessId> onBrowseOverride;
  final ValueChanged<HarnessId> onClearOverride;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final enabled = !state.isSaving;

    return HiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionHeader(
            title: l10n.settingsSectionHarnesses,
            description: l10n.settingsSectionHarnessesDescription,
          ),
          for (final id in harnesses) ...<Widget>[
            SizedBox(height: spacing.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: spacing.space3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: context.hiveRadii.card,
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: context.hiveElevation.hairline,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.space1),
                      child: HiveIcon(
                        _harnessLogo(id),
                        size: spacing.space3,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: spacing.space2),
                Expanded(
                  child: HiveTextField(
                    key: ValueKey<String>(
                      'settings_harness_${id.wireName}_field',
                    ),
                    label: _harnessLabel(id, l10n),
                    controller: controllers[id],
                    hintText: l10n.settingsHarnessPathHint,
                    errorText:
                        state.fieldErrors['harnessOverrides.${id.wireName}'],
                    enabled: enabled,
                    onChanged: (value) => onOverrideChanged(id, value),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        HiveButton(
                          key: ValueKey<String>(
                            'settings_harness_${id.wireName}_browse_button',
                          ),
                          label: l10n.settingsBrowse,
                          icon: HiveIcons.folder,
                          variant: HiveButtonVariant.ghost,
                          size: HiveButtonSize.small,
                          onPressed: enabled
                              ? () => onBrowseOverride(id)
                              : null,
                        ),
                        SizedBox(width: spacing.space1),
                        HiveButton(
                          key: ValueKey<String>(
                            'settings_harness_${id.wireName}_clear_button',
                          ),
                          label: l10n.settingsClear,
                          variant: HiveButtonVariant.ghost,
                          size: HiveButtonSize.small,
                          onPressed:
                              enabled &&
                                  (state.harnessOverridesDraft[id] ?? '')
                                      .trim()
                                      .isNotEmpty
                              ? () => onClearOverride(id)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  HiveIconData _harnessLogo(HarnessId id) => switch (id) {
    HarnessId.claudeCode => HiveIcons.harnessClaudeCode,
    HarnessId.codex => HiveIcons.harnessCodex,
    HarnessId.geminiCli => HiveIcons.harnessGeminiCli,
    HarnessId.antigravity => HiveIcons.harnessAntigravity,
  };

  String _harnessLabel(HarnessId id, AppLocalizations l10n) => switch (id) {
    HarnessId.claudeCode => l10n.settingsHarnessClaudeCode,
    HarnessId.codex => l10n.settingsHarnessCodex,
    HarnessId.geminiCli => l10n.settingsHarnessGeminiCli,
    HarnessId.antigravity => l10n.settingsHarnessAntigravity,
  };
}

class _SkillsSection extends StatelessWidget {
  const new({required this.state, required this.onAutoInstallSkillsChanged});

  final SettingsState state;
  final ValueChanged<bool> onAutoInstallSkillsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HiveCard(
      child: HiveSwitch(
        key: const ValueKey<String>('settings_auto_install_skills_switch'),
        label: l10n.settingsAutoInstallSkillsLabel,
        helperText: l10n.settingsAutoInstallSkillsHelp,
        value: state.autoInstallSkillsDraft,
        onChanged: state.isSaving ? null : onAutoInstallSkillsChanged,
      ),
    );
  }
}
