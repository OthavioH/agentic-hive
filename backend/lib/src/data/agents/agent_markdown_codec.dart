import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

const _knownFrontmatterKeys = <String>{
  'name',
  'description',
  'tags',
  'required_skills',
  'required_tools',
  'allowed_tools',
  'denied_tools',
};

/// Result of decoding an agent `.md` file from raw bytes.
final class DecodedAgentMarkdown {
  /// Creates a decoded agent record.
  const new({required this.detail, this.extraFrontmatter = const {}});

  /// The shared DTO representation (with `parseError` set on failure).
  final AgentDetail detail;

  /// Unknown top-level YAML frontmatter keys preserved for round-trip updates.
  final Map<String, Object?> extraFrontmatter;
}

/// Parses and serializes agent `.md` files with YAML frontmatter.
abstract final class AgentMarkdownCodec {
  /// Computes the deterministic SHA-256 hex digest of [bytes].
  static String computeContentHash(List<int> bytes) =>
      sha256.convert(bytes).toString();

  /// Decodes raw [bytes] of `<id>.md` into a [DecodedAgentMarkdown].
  ///
  /// Never throws on malformed content; instead returns an [AgentDetail] with
  /// [AgentDetail.parseError] and [AgentDetail.rawContent] populated.
  static DecodedAgentMarkdown decode({
    required String id,
    required List<int> bytes,
    required DateTime updatedAt,
  }) {
    final hash = computeContentHash(bytes);
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException catch (e) {
      return DecodedAgentMarkdown(
        detail: AgentDetail(
          id: id,
          name: id,
          contentHash: hash,
          updatedAt: updatedAt,
          parseError: 'Invalid UTF-8 encoding: ${e.message}',
          rawContent: utf8.decode(bytes, allowMalformed: true),
        ),
      );
    }

    final normalized = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final split = _splitFrontmatter(normalized);
    if (split == null) {
      return DecodedAgentMarkdown(
        detail: AgentDetail(
          id: id,
          name: id,
          contentHash: hash,
          updatedAt: updatedAt,
          parseError:
              'Missing or unclosed YAML frontmatter delimiters ("---").',
          rawContent: text,
        ),
      );
    }

    final Object? yamlDoc;
    try {
      yamlDoc = loadYaml(split.yaml);
    } on YamlException catch (e) {
      return DecodedAgentMarkdown(
        detail: AgentDetail(
          id: id,
          name: id,
          contentHash: hash,
          updatedAt: updatedAt,
          parseError: 'Invalid YAML frontmatter: ${e.message}',
          rawContent: text,
        ),
      );
    }

    if (yamlDoc != null && yamlDoc is! YamlMap) {
      return DecodedAgentMarkdown(
        detail: AgentDetail(
          id: id,
          name: id,
          contentHash: hash,
          updatedAt: updatedAt,
          parseError: 'YAML frontmatter must be a mapping.',
          rawContent: text,
        ),
      );
    }

    final map = yamlDoc as YamlMap?;
    final validationError = _validateKnownFields(map);
    if (validationError != null) {
      return DecodedAgentMarkdown(
        detail: AgentDetail(
          id: id,
          name: id,
          contentHash: hash,
          updatedAt: updatedAt,
          parseError: validationError,
          rawContent: text,
        ),
      );
    }

    final rawName = map?['name'] as String?;
    final name = (rawName != null && rawName.trim().isNotEmpty) ? rawName : id;
    final description = (map?['description'] as String?) ?? '';
    final tags = _stringList(map?['tags']);
    final requiredSkills = _stringList(map?['required_skills']);
    final requiredTools = _stringList(map?['required_tools']);
    final allowedTools = _stringList(map?['allowed_tools']);
    final deniedTools = _stringList(map?['denied_tools']);

    final extra = <String, Object?>{};
    if (map != null) {
      for (final entry in map.entries) {
        final key = entry.key;
        if (key is String && !_knownFrontmatterKeys.contains(key)) {
          extra[key] = _yamlToPlain(entry.value);
        }
      }
    }

    return DecodedAgentMarkdown(
      detail: AgentDetail(
        id: id,
        name: name,
        description: description,
        tags: tags,
        requiredSkills: requiredSkills,
        requiredTools: requiredTools,
        allowedTools: allowedTools,
        deniedTools: deniedTools,
        prompt: split.body,
        contentHash: hash,
        updatedAt: updatedAt,
      ),
      extraFrontmatter: extra,
    );
  }

  /// Encodes agent fields and [extraFrontmatter] into a Markdown document with
  /// YAML frontmatter.
  static String encode({
    required String name,
    required String description,
    required List<String> tags,
    required List<String> requiredSkills,
    required List<String> requiredTools,
    required List<String> allowedTools,
    required List<String> deniedTools,
    required String prompt,
    Map<String, Object?> extraFrontmatter = const {},
  }) {
    final buffer = StringBuffer()..writeln('---');
    _writeKeyValue(buffer, 'name', name);
    if (description.isNotEmpty) {
      _writeKeyValue(buffer, 'description', description);
    }
    if (tags.isNotEmpty) _writeKeyValue(buffer, 'tags', tags);
    if (requiredSkills.isNotEmpty) {
      _writeKeyValue(buffer, 'required_skills', requiredSkills);
    }
    if (requiredTools.isNotEmpty) {
      _writeKeyValue(buffer, 'required_tools', requiredTools);
    }
    if (allowedTools.isNotEmpty) {
      _writeKeyValue(buffer, 'allowed_tools', allowedTools);
    }
    if (deniedTools.isNotEmpty) {
      _writeKeyValue(buffer, 'denied_tools', deniedTools);
    }
    for (final entry in extraFrontmatter.entries) {
      if (!_knownFrontmatterKeys.contains(entry.key)) {
        _writeKeyValue(buffer, entry.key, entry.value);
      }
    }
    buffer.writeln('---');
    if (prompt.isNotEmpty) {
      buffer
        ..writeln()
        ..write(prompt);
      if (!prompt.endsWith('\n')) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  /// Converts an [AgentDetail] to its [AgentSummary].
  static AgentSummary toSummary(AgentDetail detail) => AgentSummary(
    id: detail.id,
    name: detail.name,
    description: detail.description,
    tags: detail.tags,
    contentHash: detail.contentHash,
    updatedAt: detail.updatedAt,
    scope: detail.scope,
    parseError: detail.parseError,
  );
}

({String yaml, String body})? _splitFrontmatter(String text) {
  final openMatch = RegExp(r'^---[ \t]*(?:\r?\n|$)').firstMatch(text);
  if (openMatch == null) return null;

  final afterOpen = text.substring(openMatch.end);
  final closeMatch = RegExp(
    r'^---[ \t]*(?:\r?\n|$)',
    multiLine: true,
  ).firstMatch(afterOpen);
  if (closeMatch == null) return null;

  final yamlPart = afterOpen.substring(0, closeMatch.start);
  final afterClose = afterOpen.substring(closeMatch.end);
  final body = afterClose.replaceFirst(RegExp(r'^\r?\n'), '');
  return (yaml: yamlPart, body: body);
}

String? _validateKnownFields(YamlMap? map) {
  if (map == null) return null;
  for (final stringKey in const ['name', 'description']) {
    final value = map[stringKey];
    if (value != null && value is! String) {
      return 'Frontmatter "$stringKey" must be a string.';
    }
  }
  for (final listKey in const [
    'tags',
    'required_skills',
    'required_tools',
    'allowed_tools',
    'denied_tools',
  ]) {
    final value = map[listKey];
    if (value == null) continue;
    if (value is! YamlList || value.any((e) => e is! String)) {
      return 'Frontmatter "$listKey" must be a list of strings.';
    }
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is YamlList) {
    return value.cast<String>().toList();
  }
  return const [];
}

Object? _yamlToPlain(Object? value) => switch (value) {
  YamlMap() => {
    for (final entry in value.entries)
      '${entry.key}': _yamlToPlain(entry.value),
  },
  YamlList() => [for (final item in value) _yamlToPlain(item)],
  _ => value,
};

void _writeKeyValue(
  StringBuffer buffer,
  String key,
  Object? value, {
  int indent = 0,
}) {
  final prefix = ' ' * indent;
  switch (value) {
    case null:
      buffer.writeln('$prefix$key: null');
    case bool() || num():
      buffer.writeln('$prefix$key: $value');
    case String():
      buffer.writeln('$prefix$key: ${_formatYamlString(value)}');
    case List<Object?>():
      if (value.isEmpty) {
        buffer.writeln('$prefix$key: []');
      } else {
        buffer.writeln('$prefix$key:');
        for (final item in value) {
          _writeListItem(buffer, item, indent: indent + 2);
        }
      }
    case Map<String, Object?>():
      if (value.isEmpty) {
        buffer.writeln('$prefix$key: {}');
      } else {
        buffer.writeln('$prefix$key:');
        for (final entry in value.entries) {
          _writeKeyValue(buffer, entry.key, entry.value, indent: indent + 2);
        }
      }
    default:
      buffer.writeln('$prefix$key: ${_formatYamlString(value.toString())}');
  }
}

void _writeListItem(StringBuffer buffer, Object? item, {required int indent}) {
  final prefix = ' ' * indent;
  switch (item) {
    case null:
      buffer.writeln('$prefix- null');
    case bool() || num():
      buffer.writeln('$prefix- $item');
    case String():
      buffer.writeln('$prefix- ${_formatYamlString(item)}');
    case Map<String, Object?>():
      if (item.isEmpty) {
        buffer.writeln('$prefix- {}');
      } else {
        final entries = item.entries.toList();
        final first = entries.first;
        buffer.write('$prefix- ');
        _writeKeyValue(buffer, first.key, first.value);
        for (final entry in entries.skip(1)) {
          _writeKeyValue(buffer, entry.key, entry.value, indent: indent + 2);
        }
      }
    default:
      buffer.writeln('$prefix- ${_formatYamlString(item.toString())}');
  }
}

final _safePlainScalarPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _./()-]*$');

const _yamlKeywordScalars = <String>{
  'true',
  'false',
  'null',
  'yes',
  'no',
  'on',
  'off',
  'y',
  'n',
};

String _formatYamlString(String value) {
  if (value.isEmpty ||
      value.endsWith(' ') ||
      _yamlKeywordScalars.contains(value.toLowerCase()) ||
      num.tryParse(value) != null ||
      !_safePlainScalarPattern.hasMatch(value)) {
    return jsonEncode(value);
  }
  return value;
}
