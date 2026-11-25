import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/skills/directory_bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:test/test.dart';

import 'skill_tool_names.dart';

void main() {
  late String skillText;

  setUpAll(() {
    final result = const DirectoryBundledSkillLoader('skills')
        .load('agentic-hive');
    expect(result, isA<Success<BundledSkill>>());
    final skill = (result as Success<BundledSkill>).value;
    skillText = utf8.decode(skill.files['SKILL.md']!);
  });

  group('agentic-hive SKILL.md', () {
    test('R1: frontmatter has only name and description', () {
      final match = RegExp(r'^---\n([\s\S]*?)\n---\n').firstMatch(skillText);
      expect(match, isNotNull);
      final keys = match!
          .group(1)!
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.split(':').first.trim())
          .toList();
      expect(keys, equals(['name', 'description']));
      expect(match.group(1), contains('name: agentic-hive'));
    });

    test('R2: does not mention run result contract', () {
      expect(skillText, isNot(contains('report_result')));
      expect(skillText, isNot(contains('ask_human')));
      expect(skillText, isNot(contains('result.json')));
    });

    test('R3: contains no machine paths, emails, or tokens', () {
      final forbidden = RegExp(
        r'[A-Za-z]:\\|/home/|/Users/|@[A-Za-z0-9.-]+\.[a-z]{2,}|token=',
      );
      expect(forbidden.hasMatch(skillText), isFalse);
    });

    test('R4: stays within 80 lines and 5000 characters', () {
      expect(skillText.split('\n').length, lessThanOrEqualTo(80));
      expect(skillText.length, lessThanOrEqualTo(5000));
    });

    test('R5: named tools match HiveMcpToolCatalog.backendTools', () {
      final registry = HiveMcpToolCatalog.backendTools
          .map((t) => t.name)
          .toSet();
      final named = workflowToolNamesIn(skillText);

      expect(
        named.difference(registry),
        isEmpty,
        reason: 'named in skill but not registered',
      );
      expect(
        registry.difference(named),
        isEmpty,
        reason: 'registered but not named in skill',
      );

      final editTool = HiveMcpToolCatalog.backendTools.firstWhere(
        (t) => t.name == 'edit_workflow',
      );
      final editToolSchema = jsonEncode(editTool.inputSchema);
      for (final op in editWorkflowOperationNames) {
        expect(editToolSchema, contains(op));
      }

      final withExtra = workflowToolNamesIn('$skillText\nCall `new_tool`.\n');
      expect(withExtra.difference(registry), equals({'new_tool'}));

      final withoutDelete = workflowToolNamesIn(
        skillText.replaceAll('`delete_workflow`', 'delete'),
      );
      expect(registry.difference(withoutDelete), equals({'delete_workflow'}));
    });
  });
}
