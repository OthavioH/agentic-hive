// Manual Widgetbook tree.
//
// ADR 0018 prefers `widgetbook_generator`; it is not used because no
// published release resolves in the root pub workspace. See README.md.
import 'package:hive_widgetbook/src/components/action_use_cases.dart';
import 'package:hive_widgetbook/src/components/display_use_cases.dart';
import 'package:hive_widgetbook/src/components/feedback_use_cases.dart';
import 'package:hive_widgetbook/src/components/form_use_cases.dart' as forms;
import 'package:hive_widgetbook/src/components/overlay_use_cases.dart';
import 'package:hive_widgetbook/src/foundations/icon_pages.dart';
import 'package:hive_widgetbook/src/foundations/motion_page.dart';
import 'package:hive_widgetbook/src/foundations/token_pages.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent _page(String name, WidgetBuilder builder) {
  return WidgetbookComponent(
    name: name,
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(name: 'Showcase', builder: builder),
    ],
  );
}

/// The catalog tree: token showcases, then every catalog component.
final List<WidgetbookNode> directories = <WidgetbookNode>[
  WidgetbookCategory(
    name: 'Foundations',
    children: <WidgetbookNode>[
      _page('Colors', (context) => const ColorRolesPage()),
      _page('Typography', (context) => const TypeScalePage()),
      _page('Spacing', (context) => const SpacingPage()),
      _page('Radius', (context) => const RadiusPage()),
      _page('Elevation', (context) => const ElevationPage()),
      WidgetbookComponent(
        name: 'Motion',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Flux Motion trial',
            builder: (context) => MotionPage(
              reduceMotion: context.knobs.boolean(label: 'Reduce motion'),
            ),
          ),
        ],
      ),
      _page('Icons', (context) => const IconsPage()),
      _page('Robot and harness logos', (context) => const FacesPage()),
      _page('Tray icons', (context) => const TrayIconsPage()),
    ],
  ),
  WidgetbookCategory(
    name: 'Components',
    children: <WidgetbookNode>[
      WidgetbookFolder(
        name: 'Navigation',
        children: <WidgetbookNode>[
          sideRailComponent(),
          railItemComponent(),
          hexMarkComponent(),
        ],
      ),
      WidgetbookFolder(
        name: 'Actions',
        children: <WidgetbookNode>[buttonComponent(), iconButtonComponent()],
      ),
      WidgetbookFolder(
        name: 'Forms',
        children: <WidgetbookNode>[
          forms.textFieldComponent(),
          forms.selectComponent(),
          forms.switchComponent(),
        ],
      ),
      WidgetbookFolder(
        name: 'Overlays',
        children: <WidgetbookNode>[
          WidgetbookComponent(
            name: 'HiveDialog',
            useCases: <WidgetbookUseCase>[
              ...dialogComponent().useCases,
              ...forms.dialogComponent().useCases,
            ],
          ),
        ],
      ),
      WidgetbookFolder(
        name: 'Layout',
        children: <WidgetbookNode>[
          pageHeaderComponent(),
          cardComponent(),
          emptyStateComponent(),
        ],
      ),
      WidgetbookFolder(
        name: 'Feedback',
        children: <WidgetbookNode>[toastComponent()],
      ),
      WidgetbookFolder(
        name: 'Status',
        children: <WidgetbookNode>[
          statusDotComponent(),
          badgeComponent(),
          agentAvatarComponent(),
          connectionIndicatorComponent(),
        ],
      ),
    ],
  ),
];
