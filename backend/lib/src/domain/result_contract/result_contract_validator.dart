import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Validates `report_result` and `result.json` payloads against the ADR 0003
/// result contract schema and workspace boundaries.
final class ResultContractValidator {
  /// Creates a validator using [pathContext] (defaults to host `p.context`).
  new({p.Context? pathContext}) : _path = pathContext ?? p.context;

  final p.Context _path;

  /// Returns the accepted `status` strings for [availableOutputs].
  static List<String> allowedStatusesFor(List<String> availableOutputs) {
    final allowed = <String>{};
    for (final output in availableOutputs) {
      switch (output) {
        case NodeOutput.onSuccess:
          allowed
            ..add(NodeOutput.onSuccess)
            ..add(ResultContractStatus.success.name);
        case NodeOutput.onFailure:
          allowed
            ..add(NodeOutput.onFailure)
            ..add(ResultContractStatus.failure.name);
        case NodeOutput.approved:
          allowed.add(ResultContractStatus.approved.name);
        case NodeOutput.changesRequested:
          allowed.add(ResultContractStatus.changesRequested.name);
        case 'success':
          allowed.add(ResultContractStatus.success.name);
        case 'failure':
          allowed.add(ResultContractStatus.failure.name);
      }
    }
    return allowed.toList(growable: false);
  }

  /// Validates [payload] for an attempt running in [workspacePath] with
  /// declared [availableOutputs].
  Result<ResultContractReport> validate(
    Map<String, Object?> payload, {
    required String workspacePath,
    required List<String> availableOutputs,
  }) {
    final statusResult = _parseStatus(
      payload['status'],
      availableOutputs: availableOutputs,
    );
    if (statusResult case FailureResult<ResultContractStatus>(:final failure)) {
      return FailureResult(failure);
    }

    final summaryResult = _parseSummary(payload['summary']);
    if (summaryResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final dataResult = _parseData(payload['data']);
    if (dataResult case FailureResult<Map<String, Object?>>(:final failure)) {
      return FailureResult(failure);
    }

    final artifactsResult = _parseArtifacts(
      payload['artifacts'],
      workspacePath: workspacePath,
    );
    if (artifactsResult case FailureResult<List<String>>(:final failure)) {
      return FailureResult(failure);
    }

    return Success(
      ResultContractReport(
        status: statusResult.valueOrNull!,
        summary: summaryResult.valueOrNull,
        output: dataResult.valueOrNull!,
        artifacts: artifactsResult.valueOrNull!,
      ),
    );
  }

  Result<ResultContractStatus> _parseStatus(
    Object? rawStatus, {
    required List<String> availableOutputs,
  }) {
    if (rawStatus is! String || rawStatus.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('status is required and must be a non-blank string.'),
      );
    }
    final normalized = rawStatus.trim();
    final allowed = allowedStatusesFor(availableOutputs);
    if (!allowed.contains(normalized)) {
      return FailureResult(
        ValidationFailure(
          'Invalid status "$normalized". Expected one of: '
          '${allowed.join(', ')}.',
        ),
      );
    }

    final mapped = switch (normalized) {
      NodeOutput.onSuccess || 'success' => ResultContractStatus.success,
      NodeOutput.onFailure || 'failure' => ResultContractStatus.failure,
      NodeOutput.approved => ResultContractStatus.approved,
      NodeOutput.changesRequested => ResultContractStatus.changesRequested,
      _ => null,
    };
    if (mapped == null) {
      return FailureResult(
        ValidationFailure('Unsupported status "$normalized".'),
      );
    }
    return Success(mapped);
  }

  Result<String> _parseSummary(Object? rawSummary) {
    if (rawSummary is! String || rawSummary.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure(
          'summary is required and must be a non-blank string.',
        ),
      );
    }
    return Success(rawSummary.trim());
  }

  Result<Map<String, Object?>> _parseData(Object? rawData) {
    if (rawData == null) {
      return const Success(<String, Object?>{});
    }
    if (rawData is! Map) {
      return const FailureResult(
        ValidationFailure('data must be a JSON object when provided.'),
      );
    }
    final result = <String, Object?>{};
    for (final entry in rawData.entries) {
      if (entry.key is! String) {
        return const FailureResult(
          ValidationFailure('data keys must all be strings.'),
        );
      }
      result[entry.key as String] = entry.value;
    }
    return Success(Map<String, Object?>.unmodifiable(result));
  }

  Result<List<String>> _parseArtifacts(
    Object? rawArtifacts, {
    required String workspacePath,
  }) {
    if (rawArtifacts == null) {
      return const Success(<String>[]);
    }
    if (rawArtifacts is! List) {
      return const FailureResult(
        ValidationFailure(
          'artifacts must be a list of workspace-relative paths.',
        ),
      );
    }

    final normalizedRoot = _path.normalize(_path.absolute(workspacePath));
    final canonicalRoot = _resolveCanonicalPath(normalizedRoot);
    final validated = <String>[];

    for (final item in rawArtifacts) {
      if (item is! String || item.trim().isEmpty) {
        return const FailureResult(
          ValidationFailure(
            'Each artifact path must be a non-empty relative string.',
          ),
        );
      }
      final artifact = item.trim();
      if (_path.isAbsolute(artifact) ||
          RegExp('^[a-zA-Z]:').hasMatch(artifact) ||
          artifact.startsWith('/') ||
          artifact.startsWith(r'\')) {
        return FailureResult(
          ValidationFailure(
            'Artifact "$artifact" must be a workspace-relative path.',
          ),
        );
      }

      final resolved = _path.normalize(_path.join(normalizedRoot, artifact));
      if (resolved != normalizedRoot &&
          !_path.isWithin(normalizedRoot, resolved)) {
        return FailureResult(
          ValidationFailure('Artifact "$artifact" escapes the workspace root.'),
        );
      }

      final canonicalTarget = _resolveCanonicalPath(resolved);
      if (canonicalTarget != canonicalRoot &&
          !_path.isWithin(canonicalRoot, canonicalTarget)) {
        return FailureResult(
          ValidationFailure(
            'Artifact "$artifact" escapes the workspace root via symlink.',
          ),
        );
      }
      validated.add(artifact);
    }

    return Success(List<String>.unmodifiable(validated));
  }

  String _resolveCanonicalPath(String targetPath) {
    final missingSegments = <String>[];
    var current = _path.normalize(targetPath);

    while (FileSystemEntity.typeSync(current) ==
        FileSystemEntityType.notFound) {
      if (FileSystemEntity.typeSync(current, followLinks: false) ==
          FileSystemEntityType.link) {
        try {
          final linkTarget = Link(current).targetSync();
          final resolvedLink = _path.isAbsolute(linkTarget)
              ? linkTarget
              : _path.join(_path.dirname(current), linkTarget);
          current = _path.normalize(resolvedLink);
          continue;
        } on FileSystemException {
          break;
        }
      }
      final parent = _path.dirname(current);
      if (parent == current) break;
      missingSegments.add(_path.basename(current));
      current = parent;
    }

    var canonicalBase = current;
    if (FileSystemEntity.typeSync(current) != FileSystemEntityType.notFound) {
      try {
        canonicalBase = Directory(current).existsSync()
            ? Directory(current).resolveSymbolicLinksSync()
            : File(current).resolveSymbolicLinksSync();
      } on FileSystemException {
        canonicalBase = current;
      }
    }

    if (missingSegments.isEmpty) {
      return _path.normalize(canonicalBase);
    }
    return _path.normalize(
      _path.joinAll(<String>[canonicalBase, ...missingSegments.reversed]),
    );
  }
}
