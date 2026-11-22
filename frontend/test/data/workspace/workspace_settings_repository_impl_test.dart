import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  JsonMap? lastBody;
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    return nextResponse;
  }

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) =>
      sendJsonRequest('GET', path);

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) => sendJsonRequest('POST', path, body: body);

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) =>
      sendJsonRequest('PUT', path, body: body);

  @override
  Future<Result<void>> delete(String path) async => const Success(null);

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

const _responseJson = <String, Object?>{
  'overrides': <String, Object?>{'defaultShell': 'pwsh'},
  'global': <String, Object?>{
    'defaultIsolationMode': 'worktree',
    'ignorePatterns': <Object?>[],
    'defaultShell': 'cmd.exe',
  },
  'effective': <String, Object?>{
    'defaultIsolationMode': 'worktree',
    'ignorePatterns': <Object?>[],
    'defaultShell': 'pwsh',
  },
};

void main() {
  late _FakeBackendClient client;
  late ProviderContainer container;

  setUp(() {
    client = _FakeBackendClient();
    container = ProviderContainer.test(
      overrides: [backendClientProvider.overrideWithValue(client)],
    );
  });

  test('getSettings reads the workspace settings route', () async {
    client.nextResponse = const Success(_responseJson);

    final result = await container
        .read(workspaceSettingsRepositoryProvider)
        .getSettings('ws 1');

    expect(client.lastMethod, 'GET');
    expect(client.lastPath, '/api/v1/workspaces/ws%201/settings');
    expect(result.valueOrNull?.overrides.defaultShell, 'pwsh');
    expect(result.valueOrNull?.global.defaultShell, 'cmd.exe');
  });

  test('updateSettings PUTs only the set override keys', () async {
    client.nextResponse = const Success(_responseJson);

    final result = await container
        .read(workspaceSettingsRepositoryProvider)
        .updateSettings(
          'ws-1',
          const ExecutionSettings(
            defaultIsolationMode: WorkspaceIsolationMode.direct,
            defaultShell: 'pwsh',
          ),
        );

    expect(client.lastMethod, 'PUT');
    expect(client.lastPath, '/api/v1/workspaces/ws-1/settings');
    expect(client.lastBody, <String, Object?>{
      'defaultIsolationMode': 'direct',
      'defaultShell': 'pwsh',
    });
    expect(result.isSuccess, isTrue);
  });

  test('a malformed payload becomes a BackendFailure', () async {
    client.nextResponse = const Success(<String, Object?>{'overrides': 1});

    final result = await container
        .read(workspaceSettingsRepositoryProvider)
        .getSettings('ws-1');

    expect(result.failureOrNull, isA<BackendFailure>());
  });

  test('transport failures pass through', () async {
    client.nextResponse = const FailureResult(NetworkFailure('down'));

    final result = await container
        .read(workspaceSettingsRepositoryProvider)
        .getSettings('ws-1');

    expect(result.failureOrNull, isA<NetworkFailure>());
  });
}
