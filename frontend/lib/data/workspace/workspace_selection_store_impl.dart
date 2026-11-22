import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';

/// File-backed [WorkspaceSelectionStore] writing `current_workspace.json`
/// inside [PlatformPaths.defaultDataDir].
final class FileWorkspaceSelectionStore implements WorkspaceSelectionStore {
  /// Creates a [FileWorkspaceSelectionStore].
  const new(this._platformPaths);

  static const String _fileName = 'current_workspace.json';

  final PlatformPaths _platformPaths;

  File get _file => File(
    _platformPaths.context.join(_platformPaths.defaultDataDir(), _fileName),
  );

  @override
  Future<String?> load() async {
    try {
      final file = _file;
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final id = decoded['workspaceId'];
        if (id is String && id.isNotEmpty) {
          return id;
        }
      }
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String? workspaceId) async {
    final file = _file;
    if (workspaceId == null || workspaceId.isEmpty) {
      if (file.existsSync()) {
        await file.delete();
      }
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, String>{'workspaceId': workspaceId}),
    );
  }
}
