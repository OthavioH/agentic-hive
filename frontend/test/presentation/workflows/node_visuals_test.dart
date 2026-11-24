import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'createNodeVisualRegistry registers all 10 canonical NodeDescriptors',
    (tester) async {
      final registry = createNodeVisualRegistry();

      // fan_out visual is added by ticket 130-W (#143), which removes this
      // exclusion.
      for (final descriptor in NodeDescriptors.all.where(
        (d) => d.typeId != NodeTypeId.fanOut,
      )) {
        expect(
          registry.contains(descriptor.typeId),
          isTrue,
          reason: '${descriptor.typeId} must be registered',
        );
        final visual = registry.resolve(descriptor.typeId);
        expect(visual, isNot(equals(NodeVisual.fallback)));
      }

      final humanVisual = registry.resolve(NodeTypeId.humanApproval);
      expect(humanVisual.icon, HiveIcons.person);
      expect(humanVisual.accent, isNotNull);
      expect(humanVisual.accent!(HiveColors.dark), HiveColors.dark.warning);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              // fan_out visual is added by ticket 130-W (#143), which removes this
      // exclusion.
              for (final descriptor in NodeDescriptors.all.where(
                (d) => d.typeId != NodeTypeId.fanOut,
              )) {
                final label = resolveNodeVisualLabel(
                  l10n,
                  registry.resolve(descriptor.typeId).labelKey,
                );
                expect(label, isNotEmpty);
                expect(label, isNot(l10n.nodeTypeUnknown));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );
}
