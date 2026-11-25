import 'package:test/test.dart';

import '../../../tool/src/hive/quality_gate_plan.dart';

void main() {
  test('a shared change tests shared and its dependents', () {
    expect(affectedPackages(['shared/lib/src/x.dart']), {
      WorkspacePackage.shared,
      WorkspacePackage.backend,
      WorkspacePackage.frontend,
    });
  });

  test('a design system change tests its dependents', () {
    expect(affectedPackages(['design_system/lib/a.dart']), {
      WorkspacePackage.designSystem,
      WorkspacePackage.widgetbook,
      WorkspacePackage.frontend,
    });
  });

  test('tool and root tests map to the root package', () {
    expect(affectedPackages(['tool/hive/x.dart', 'test/tool/y.dart']), {
      WorkspacePackage.root,
    });
  });

  test('hive_lints maps to its package; other tools folders do not', () {
    expect(affectedPackages(['tools/hive_lints/lib/a.dart']), {
      WorkspacePackage.hiveLints,
    });
    expect(affectedPackages(['tools/other/a.dart']), isEmpty);
  });

  test('docs, agents and CI files need no tests', () {
    expect(
      affectedPackages([
        'docs/adrs/0001.md',
        '.agents/agents/a.md',
        '.github/workflows/ci.yml',
      ]),
      isEmpty,
    );
  });
}
