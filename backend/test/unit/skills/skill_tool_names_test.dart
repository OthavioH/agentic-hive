import 'package:agentic_hive_backend/src/skills/skill_tool_names.dart';
import 'package:test/test.dart';

void main() {
  group('workflowToolNamesIn', () {
    test('returns backticked snake_case names', () {
      const md = 'Call `list_workspaces` and `get_workflow` first.';
      expect(
        workflowToolNamesIn(md),
        equals({'list_workspaces', 'get_workflow'}),
      );
    });

    test('ignores plain words and single-word code', () {
      const md = 'Use `hive` with `workspace`, `revision`, and `global`.';
      expect(workflowToolNamesIn(md), isEmpty);
    });

    test('ignores frontmatter', () {
      const md = '''
---
name: agentic_hive
description: Uses `fake_frontmatter_tool` in frontmatter.
---

Call `list_workflows` now.
''';
      expect(workflowToolNamesIn(md), equals({'list_workflows'}));
    });

    test('excludes the seven edit_workflow operation names', () {
      const md = '''
Use `get_workflow` and `edit_workflow` with `add_node`, `update_node`,
`remove_node`, `connect`, `disconnect`, `set_entry`, and `set_meta`.
''';
      expect(
        workflowToolNamesIn(md),
        equals({'get_workflow', 'edit_workflow'}),
      );
    });
  });
}
