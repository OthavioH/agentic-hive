import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outdated_tools_controller.g.dart';

/// A harness whose skill or MCP installation is outdated relative to the
/// current app bundle.
@immutable
final class OutdatedHarness {
  /// Creates an [OutdatedHarness].
  const new({
    required this.id,
    required this.displayName,
    required this.skillOutdated,
    required this.mcpOutdated,
  });

  /// Harness identifier.
  final HarnessId id;

  /// Human-readable harness name.
  final String displayName;

  /// Whether the Agentic Hive skill is outdated.
  final bool skillOutdated;

  /// Whether the Hive MCP server entry is outdated.
  final bool mcpOutdated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutdatedHarness &&
          other.id == id &&
          other.displayName == displayName &&
          other.skillOutdated == skillOutdated &&
          other.mcpOutdated == mcpOutdated;

  @override
  int get hashCode => Object.hash(id, displayName, skillOutdated, mcpOutdated);
}

/// Tracks the app version for which the outdated-tools banner was dismissed or
/// acknowledged by opening Harnesses.
@Riverpod(keepAlive: true)
class OutdatedBannerAcknowledgement extends _$OutdatedBannerAcknowledgement {
  @override
  Future<String?> build() =>
      ref.watch(getAcknowledgedOutdatedVersionUseCaseProvider)();

  /// Marks the current [appVersionProvider] value as acknowledged in memory
  /// immediately and persists it best-effort to disk.
  Future<void> acknowledge() async {
    final version = ref.read(appVersionProvider);
    if (version == null) return;
    state = AsyncData<String?>(version);
    try {
      await ref.read(acknowledgeOutdatedVersionUseCaseProvider)(version);
    } on Object {
      // Keep the in-memory acknowledgement even if disk persistence fails.
    }
  }
}

/// Harnesses with a skill row whose skill or MCP is currently outdated.
@riverpod
List<OutdatedHarness> outdatedHarnesses(Ref ref) {
  final harnesses = ref
      .watch(harnessesControllerProvider)
      .asData
      ?.value
      .harnesses;
  if (harnesses == null) return const <OutdatedHarness>[];
  return <OutdatedHarness>[
    for (final harness in harnesses)
      if (harness.skillStatus != null &&
          (harness.skillStatus == HarnessSkillStatus.outdated ||
              harness.mcpStatus == HarnessMcpStatus.outdated))
        OutdatedHarness(
          id: harness.id,
          displayName: harness.displayName,
          skillOutdated: harness.skillStatus == HarnessSkillStatus.outdated,
          mcpOutdated: harness.mcpStatus == HarnessMcpStatus.outdated,
        ),
  ];
}

/// Whether the global outdated-tools banner should be shown for the current
/// app version.
@riverpod
bool showOutdatedBanner(Ref ref) {
  final outdated = ref.watch(outdatedHarnessesProvider);
  final version = ref.watch(appVersionProvider);
  final acknowledgement = ref.watch(outdatedBannerAcknowledgementProvider);
  return outdated.isNotEmpty &&
      version != null &&
      acknowledgement.hasValue &&
      acknowledgement.value != version;
}
