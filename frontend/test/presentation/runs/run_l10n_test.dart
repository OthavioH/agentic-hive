import 'dart:ui';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('RunL10n preparing', () {
    test('maps RunStatus.preparing to Preparing, idle dot, and info badge', () {
      expect(RunL10n.localizeStatus(l10n, RunStatus.preparing), 'Preparing');
      expect(RunL10n.nodeStatusFor(RunStatus.preparing), HiveNodeStatus.idle);
      expect(RunL10n.badgeToneFor(RunStatus.preparing), HiveBadgeTone.info);
    });

    test('maps RunEventType.runPreparing to info tone', () {
      expect(
        RunL10n.eventToneFor(RunEventType.runPreparing),
        HiveBadgeTone.info,
      );
    });
  });
}
