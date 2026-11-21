import 'dart:convert';

import 'package:agentic_hive_backend/src/data/agents/agent_markdown_codec.dart';
import 'package:test/test.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 11, 20, 12);

  group('AgentMarkdownCodec', () {
    test('round-trips frontmatter, capabilities, and prompt', () {
      final markdown = AgentMarkdownCodec.encode(
        name: 'Code Reviewer: Strict',
        description: 'Reviews #10 PRs carefully.',
        tags: const ['review', 'qa'],
        requiredSkills: const ['dart-validation'],
        requiredTools: const ['read_file'],
        allowedTools: const ['read_file', 'grep'],
        deniedTools: const ['run_command'],
        prompt: '# Responsibilities\nCheck edge cases.',
      );

      final decoded = AgentMarkdownCodec.decode(
        id: 'reviewer',
        bytes: utf8.encode(markdown),
        updatedAt: updatedAt,
      );

      expect(decoded.detail.parseError, isNull);
      expect(decoded.detail.rawContent, isNull);
      expect(decoded.detail.id, 'reviewer');
      expect(decoded.detail.name, 'Code Reviewer: Strict');
      expect(decoded.detail.description, 'Reviews #10 PRs carefully.');
      expect(decoded.detail.tags, ['review', 'qa']);
      expect(decoded.detail.requiredSkills, ['dart-validation']);
      expect(decoded.detail.requiredTools, ['read_file']);
      expect(decoded.detail.allowedTools, ['read_file', 'grep']);
      expect(decoded.detail.deniedTools, ['run_command']);
      expect(decoded.detail.prompt, '# Responsibilities\nCheck edge cases.\n');
    });

    test('preserves unknown top-level YAML keys on round-trip', () {
      const source = '''
---
name: Custom Agent
author: external-tool
custom_nested:
  retries: 3
  flag: true
---

Do work.
''';
      final first = AgentMarkdownCodec.decode(
        id: 'custom',
        bytes: utf8.encode(source),
        updatedAt: updatedAt,
      );
      expect(first.extraFrontmatter, {
        'author': 'external-tool',
        'custom_nested': {'retries': 3, 'flag': true},
      });

      final reencoded = AgentMarkdownCodec.encode(
        name: 'Renamed Custom Agent',
        description: 'Updated description',
        tags: const ['t1'],
        requiredSkills: const [],
        requiredTools: const [],
        allowedTools: const [],
        deniedTools: const [],
        prompt: 'Updated prompt.',
        extraFrontmatter: first.extraFrontmatter,
      );

      final second = AgentMarkdownCodec.decode(
        id: 'custom',
        bytes: utf8.encode(reencoded),
        updatedAt: updatedAt,
      );
      expect(second.detail.name, 'Renamed Custom Agent');
      expect(second.extraFrontmatter, first.extraFrontmatter);
    });

    test('surfaces parseError for missing frontmatter', () {
      const raw = '# Just markdown\nNo frontmatter here.';
      final decoded = AgentMarkdownCodec.decode(
        id: 'plain',
        bytes: utf8.encode(raw),
        updatedAt: updatedAt,
      );

      expect(decoded.detail.parseError, isNotNull);
      expect(decoded.detail.rawContent, raw);
      expect(decoded.detail.name, 'plain');
    });

    test('surfaces parseError for broken YAML', () {
      const raw = '---\nname: [unclosed\n---\nPrompt';
      final decoded = AgentMarkdownCodec.decode(
        id: 'broken-yaml',
        bytes: utf8.encode(raw),
        updatedAt: updatedAt,
      );

      expect(decoded.detail.parseError, contains('Invalid YAML'));
      expect(decoded.detail.rawContent, raw);
    });

    test('surfaces parseError for invalid field types', () {
      const raw = '---\nname: Test\ntags: not-a-list\n---\nPrompt';
      final decoded = AgentMarkdownCodec.decode(
        id: 'bad-tags',
        bytes: utf8.encode(raw),
        updatedAt: updatedAt,
      );

      expect(decoded.detail.parseError, contains('"tags"'));
      expect(decoded.detail.rawContent, raw);
    });

    test('surfaces parseError for invalid UTF-8 bytes', () {
      final bytes = <int>[0xFF, 0xFE, 0xFD];
      final decoded = AgentMarkdownCodec.decode(
        id: 'bad-utf8',
        bytes: bytes,
        updatedAt: updatedAt,
      );

      expect(decoded.detail.parseError, contains('UTF-8'));
      expect(decoded.detail.rawContent, isNotNull);
      expect(
        decoded.detail.contentHash,
        AgentMarkdownCodec.computeContentHash(bytes),
      );
    });
  });
}
