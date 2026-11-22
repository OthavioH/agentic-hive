import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Workspace', () {
    test('round-trips through JSON', () {
      final workspace = Workspace(
        id: 'ws-1',
        name: 'My project',
        rootPath: '/home/me/project',
        isGit: true,
        createdAt: DateTime.utc(2026, 11, 22, 10),
        updatedAt: DateTime.utc(2026, 11, 22, 11),
        activeRunCount: 2,
      );

      final decoded = Workspace.fromJson(workspace.toJson());

      expect(decoded, workspace);
      expect(workspace.toJson()['isGit'], isTrue);
      expect(workspace.toJson()['activeRunCount'], 2);
    });

    test('defaults activeRunCount to zero', () {
      final decoded = Workspace.fromJson({
        'id': 'ws-1',
        'name': 'n',
        'rootPath': '/p',
        'isGit': false,
        'createdAt': '2026-11-22T10:00:00.000Z',
        'updatedAt': '2026-11-22T10:00:00.000Z',
      });

      expect(decoded.activeRunCount, 0);
      expect(decoded.isGit, isFalse);
    });

    test('throws FormatException on a bad shape', () {
      expect(() => Workspace.fromJson({'id': 'ws-1'}), throwsFormatException);
    });
  });

  group('workspace DTOs', () {
    test('CreateWorkspaceRequest name is optional', () {
      final request = CreateWorkspaceRequest.fromJson({'rootPath': '/p'});

      expect(request.rootPath, '/p');
      expect(request.name, isNull);
    });

    test('UpdateWorkspaceRequest round-trips', () {
      const request = UpdateWorkspaceRequest(name: 'New');

      expect(UpdateWorkspaceRequest.fromJson(request.toJson()), request);
    });

    test('WorkspaceListResponse round-trips', () {
      final response = WorkspaceListResponse(
        items: [
          Workspace(
            id: 'ws-1',
            name: 'n',
            rootPath: '/p',
            isGit: false,
            createdAt: DateTime.utc(2026, 11, 22),
            updatedAt: DateTime.utc(2026, 11, 22),
          ),
        ],
      );

      expect(WorkspaceListResponse.fromJson(response.toJson()), response);
    });
  });

  group('run linkage', () {
    test('StartRunRequest accepts workspaceId without workspacePath', () {
      final request = StartRunRequest.fromJson({
        'workflowId': 'wf-1',
        'workspaceId': 'ws-1',
      });

      expect(request.workspaceId, 'ws-1');
      expect(request.workspacePath, isNull);
    });
  });
}
