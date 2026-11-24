import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:test/test.dart';

void main() {
  group('computeSkillContentHash', () {
    test('produces 64 lowercase hex characters', () {
      final hash = computeSkillContentHash({'SKILL.md': utf8.encode('a')});
      expect(hash, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('matches pinned golden for SKILL.md -> "a"', () {
      final hash = computeSkillContentHash({'SKILL.md': utf8.encode('a')});
      expect(
        hash,
        'dabde7ae00d669dfe4b03ec513e2d93709f86fe57a4a9a883b0ba7a7c7aa3ba4',
      );
    });

    test('is independent of map insertion order', () {
      final first = computeSkillContentHash({
        'SKILL.md': utf8.encode('hello'),
        'references/a.md': utf8.encode('world'),
      });
      final second = computeSkillContentHash({
        'references/a.md': utf8.encode('world'),
        'SKILL.md': utf8.encode('hello'),
      });
      expect(first, equals(second));
    });

    test(
      'changes when a byte changes, a key is renamed, or a file is added',
      () {
        final base = computeSkillContentHash({
          'SKILL.md': utf8.encode('hello'),
        });
        final changedByte = computeSkillContentHash({
          'SKILL.md': utf8.encode('hellO'),
        });
        final renamedKey = computeSkillContentHash({
          'OTHER.md': utf8.encode('hello'),
        });
        final addedFile = computeSkillContentHash({
          'SKILL.md': utf8.encode('hello'),
          'extra.txt': utf8.encode('x'),
        });

        expect(changedByte, isNot(equals(base)));
        expect(renamedKey, isNot(equals(base)));
        expect(addedFile, isNot(equals(base)));
      },
    );
  });
}
