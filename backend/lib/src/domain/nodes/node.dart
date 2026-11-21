import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Abstract base for every executable workflow node (ADR 0006).
abstract base class Node {
  /// Creates a node.
  const new();

  /// Canonical `WorkflowNode.type` identifier.
  String get typeId;

  /// Shared descriptor for this node type.
  NodeDescriptor get descriptor => NodeDescriptors.of(typeId)!;

  /// Output edge labels this node can emit.
  List<String> get availableOutputs => descriptor.availableOutputs;

  /// Validates [config] against this node's schema and rules.
  List<NodeConfigIssue> validateConfig(JsonMap config) =>
      descriptor.validateConfig(config);

  /// Executes this node within [context].
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context);

  /// Resolves [relativePath] inside [workspacePath], returning a
  /// [ValidationFailure] if it is absolute or escapes the workspace
  /// (including through symbolic links).
  Result<String> resolveWorkspacePath(
    String workspacePath,
    String? relativePath, {
    String fieldName = 'workingDirectory',
  }) {
    final normalizedRoot = p.normalize(p.absolute(workspacePath));
    final canonicalRoot = _resolveCanonicalPath(normalizedRoot);
    if (relativePath == null || relativePath.trim().isEmpty) {
      return Success(canonicalRoot);
    }

    if (p.isAbsolute(relativePath) ||
        RegExp('^[a-zA-Z]:').hasMatch(relativePath)) {
      return FailureResult(
        ValidationFailure('$fieldName must be a relative path.'),
      );
    }

    final resolved = p.normalize(p.join(normalizedRoot, relativePath));
    if (resolved != normalizedRoot && !p.isWithin(normalizedRoot, resolved)) {
      return FailureResult(
        ValidationFailure('$fieldName must stay within the workspace.'),
      );
    }

    final canonicalTarget = _resolveCanonicalPath(resolved);
    if (canonicalTarget != canonicalRoot &&
        !p.isWithin(canonicalRoot, canonicalTarget)) {
      return FailureResult(
        ValidationFailure('$fieldName must stay within the workspace.'),
      );
    }
    return Success(canonicalTarget);
  }

  String _resolveCanonicalPath(String targetPath) {
    final missingSegments = <String>[];
    var current = p.normalize(targetPath);

    while (FileSystemEntity.typeSync(current) ==
        FileSystemEntityType.notFound) {
      // Also check for dangling symlinks so they cannot bypass containment.
      if (FileSystemEntity.typeSync(current, followLinks: false) ==
          FileSystemEntityType.link) {
        try {
          final linkTarget = Link(current).targetSync();
          final resolvedLink = p.isAbsolute(linkTarget)
              ? linkTarget
              : p.join(p.dirname(current), linkTarget);
          current = p.normalize(resolvedLink);
          continue;
        } on FileSystemException {
          break;
        }
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      missingSegments.add(p.basename(current));
      current = parent;
    }

    var canonicalBase = current;
    if (FileSystemEntity.typeSync(current) != FileSystemEntityType.notFound) {
      try {
        canonicalBase = File(current).resolveSymbolicLinksSync();
      } on FileSystemException {
        canonicalBase = current;
      }
    }

    if (missingSegments.isEmpty) {
      return p.normalize(canonicalBase);
    }
    return p.normalize(
      p.joinAll(<String>[canonicalBase, ...missingSegments.reversed]),
    );
  }
}
