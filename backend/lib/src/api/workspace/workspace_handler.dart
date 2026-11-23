import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

/// HTTP handler for workspace capabilities and run snapshot routes.
final class WorkspaceHandler {
  /// Creates a workspace handler.
  const new({required this._capabilities, required this._snapshots});

  final WorkspaceCapabilitiesService _capabilities;
  final ShadowSnapshotService _snapshots;

  /// `GET /api/v1/workspace/capabilities` (optional `?path=...`).
  Future<Response> capabilities(Request request) async {
    final path = request.url.queryParameters['path'];
    if (path != null && path.trim().isNotEmpty && !p.isAbsolute(path)) {
      return failureResponse(
        request,
        const ValidationFailure('Query parameter "path" must be absolute.'),
      );
    }
    final result = await _capabilities.getCapabilities(path: path);
    return _mapResult(request, result, 200);
  }

  /// `GET /api/v1/runs/<id>/snapshots`.
  Future<Response> listSnapshots(Request request, String id) async {
    final result = await _snapshots.listSnapshots(id);
    return _mapResult(request, result, 200);
  }

  /// `GET /api/v1/runs/<id>/snapshots/<snapshotId>/diff`.
  Future<Response> getDiff(
    Request request,
    String id,
    String snapshotId,
  ) async {
    final result = await _snapshots.getSnapshotDiff(id, snapshotId);
    return _mapResult(request, result, 200);
  }

  /// `POST /api/v1/runs/<id>/snapshots/<snapshotId>/restore`.
  Future<Response> restoreSnapshot(
    Request request,
    String id,
    String snapshotId,
  ) async {
    final result = await _snapshots.restoreSnapshot(id, snapshotId);
    return _mapResult(request, result, 200);
  }

  Response _mapResult<T>(Request request, Result<T> result, int okStatus) =>
      switch (result) {
        Success<T>(:final value) => jsonResponse(okStatus, value),
        FailureResult<T>(:final failure) => failureResponse(request, failure),
      };
}
