import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_markdown_codec.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// File-system backed [AgentRepository] storing `<id>.md` files in
/// [agentsDir].
final class LocalAgentRepository implements AgentRepository {
  /// Creates a repository rooted at [agentsDir] using [pathContext].
  new({
    required this.agentsDir,
    this.scope = const GlobalScope(),
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context;

  /// Scope stamped on every agent this repository returns.
  final DefinitionScope scope;

  /// Directory containing flat `<id>.md` agent files.
  String agentsDir;

  final p.Context _path;

  /// Ensures [agentsDir] exists on disk.
  Future<void> ensureDirectory() =>
      Directory(agentsDir).create(recursive: true);

  File? _safeFileFor(String id) {
    if (id.isEmpty ||
        id.startsWith('.') ||
        id.contains('/') ||
        id.contains(r'\') ||
        id.contains('..') ||
        id.contains('\u0000')) {
      return null;
    }
    final root = _path.normalize(agentsDir);
    final candidate = _path.normalize(_path.join(root, '$id.md'));
    if (!_path.equals(_path.dirname(candidate), root)) {
      return null;
    }
    return File(candidate);
  }

  @override
  Future<Result<List<AgentSummary>>> list() async {
    try {
      final dir = Directory(agentsDir);
      if (!dir.existsSync()) {
        return const Success(<AgentSummary>[]);
      }
      final summaries = <AgentSummary>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (_path.extension(entity.path).toLowerCase() != '.md') continue;

        final id = _path.basenameWithoutExtension(entity.path);
        if (id.isEmpty || id.startsWith('.') || id.contains('..')) continue;
        final bytes = await entity.readAsBytes();
        final stat = entity.statSync();
        final decoded = AgentMarkdownCodec.decode(
          id: id,
          bytes: bytes,
          updatedAt: stat.modified.toUtc(),
        );
        summaries.add(
          AgentMarkdownCodec.toSummary(decoded.detail.copyWith(scope: scope)),
        );
      }
      summaries.sort((a, b) => a.id.compareTo(b.id));
      return Success(summaries);
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to list agents in $agentsDir.', cause: e),
      );
    }
  }

  @override
  Future<Result<AgentDetail>> getById(String id) async {
    try {
      final file = _safeFileFor(id);
      if (file == null) {
        return FailureResult(
          ValidationFailure('Invalid agent filename id "$id".'),
        );
      }
      if (!file.existsSync()) {
        return FailureResult(NotFoundFailure('Agent "$id" not found.'));
      }
      final bytes = await file.readAsBytes();
      final stat = file.statSync();
      final decoded = AgentMarkdownCodec.decode(
        id: id,
        bytes: bytes,
        updatedAt: stat.modified.toUtc(),
      );
      return Success(decoded.detail.copyWith(scope: scope));
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to read agent "$id".', cause: e),
      );
    }
  }

  @override
  Future<Result<AgentDetail>> create(CreateAgentRequest request) async {
    try {
      await ensureDirectory();
      final file = _safeFileFor(request.id);
      if (file == null) {
        return FailureResult(
          ValidationFailure('Invalid agent filename id "${request.id}".'),
        );
      }
      if (file.existsSync()) {
        return FailureResult(
          ConflictFailure('Agent "${request.id}" already exists.'),
        );
      }

      final markdown = AgentMarkdownCodec.encode(
        name: request.name,
        description: request.description,
        tags: request.tags,
        requiredSkills: request.requiredSkills,
        requiredTools: request.requiredTools,
        allowedTools: request.allowedTools,
        deniedTools: request.deniedTools,
        prompt: request.prompt,
      );
      final bytes = utf8.encode(markdown);
      await file.writeAsBytes(bytes, flush: true);
      final stat = file.statSync();

      return Success(
        AgentDetail(
          id: request.id,
          name: request.name,
          description: request.description,
          tags: request.tags,
          requiredSkills: request.requiredSkills,
          requiredTools: request.requiredTools,
          allowedTools: request.allowedTools,
          deniedTools: request.deniedTools,
          prompt: request.prompt,
          scope: scope,
          contentHash: AgentMarkdownCodec.computeContentHash(bytes),
          updatedAt: stat.modified.toUtc(),
        ),
      );
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to create agent "${request.id}".', cause: e),
      );
    }
  }

  @override
  Future<Result<AgentDetail>> update(
    String id,
    UpdateAgentRequest request,
  ) async {
    try {
      final file = _safeFileFor(id);
      if (file == null) {
        return FailureResult(
          ValidationFailure('Invalid agent filename id "$id".'),
        );
      }
      if (!file.existsSync()) {
        return FailureResult(NotFoundFailure('Agent "$id" not found.'));
      }

      final existingBytes = await file.readAsBytes();
      final currentHash = AgentMarkdownCodec.computeContentHash(existingBytes);
      if (currentHash != request.expectedHash) {
        return FailureResult(
          ConflictFailure(
            'Agent "$id" was modified externally '
            '(expected hash ${request.expectedHash}, found $currentHash).',
          ),
        );
      }

      final stat = file.statSync();
      final existing = AgentMarkdownCodec.decode(
        id: id,
        bytes: existingBytes,
        updatedAt: stat.modified.toUtc(),
      );
      if (existing.detail.parseError != null) {
        return FailureResult(
          ValidationFailure(
            'Agent "$id" cannot be updated because the file on disk has a '
            'parse error: ${existing.detail.parseError}',
          ),
        );
      }

      final markdown = AgentMarkdownCodec.encode(
        name: request.name,
        description: request.description,
        tags: request.tags,
        requiredSkills: request.requiredSkills,
        requiredTools: request.requiredTools,
        allowedTools: request.allowedTools,
        deniedTools: request.deniedTools,
        prompt: request.prompt,
        extraFrontmatter: existing.extraFrontmatter,
      );
      final newBytes = utf8.encode(markdown);
      await file.writeAsBytes(newBytes, flush: true);
      final updatedStat = file.statSync();

      return Success(
        AgentDetail(
          id: id,
          name: request.name,
          description: request.description,
          tags: request.tags,
          requiredSkills: request.requiredSkills,
          requiredTools: request.requiredTools,
          allowedTools: request.allowedTools,
          deniedTools: request.deniedTools,
          prompt: request.prompt,
          scope: scope,
          contentHash: AgentMarkdownCodec.computeContentHash(newBytes),
          updatedAt: updatedStat.modified.toUtc(),
        ),
      );
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to update agent "$id".', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final file = _safeFileFor(id);
      if (file == null) {
        return FailureResult(
          ValidationFailure('Invalid agent filename id "$id".'),
        );
      }
      if (!file.existsSync()) {
        return FailureResult(NotFoundFailure('Agent "$id" not found.'));
      }
      await file.delete();
      return const Success<void>(null);
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to delete agent "$id".', cause: e),
      );
    }
  }
}
