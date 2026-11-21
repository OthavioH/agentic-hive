// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_connection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks connectivity to the local backend, manages the live WebSocket
/// session, and drives automatic reconnection with exponential backoff and a
/// 2-second silent grace period on drop.

@ProviderFor(BackendConnection)
final backendConnectionProvider = BackendConnectionProvider._();

/// Tracks connectivity to the local backend, manages the live WebSocket
/// session, and drives automatic reconnection with exponential backoff and a
/// 2-second silent grace period on drop.
final class BackendConnectionProvider
    extends $NotifierProvider<BackendConnection, BackendConnectionState> {
  /// Tracks connectivity to the local backend, manages the live WebSocket
  /// session, and drives automatic reconnection with exponential backoff and a
  /// 2-second silent grace period on drop.
  BackendConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendConnectionHash();

  @$internal
  @override
  BackendConnection create() => BackendConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendConnectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendConnectionState>(value),
    );
  }
}

String _$backendConnectionHash() => r'76916e412efacf58a7521ab33c6e7f7b44095277';

/// Tracks connectivity to the local backend, manages the live WebSocket
/// session, and drives automatic reconnection with exponential backoff and a
/// 2-second silent grace period on drop.

abstract class _$BackendConnection extends $Notifier<BackendConnectionState> {
  BackendConnectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<BackendConnectionState, BackendConnectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackendConnectionState, BackendConnectionState>,
              BackendConnectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Exposes the active [BackendWebSocketSession] when connected, or `null`.

@ProviderFor(backendWebSocketSession)
final backendWebSocketSessionProvider = BackendWebSocketSessionProvider._();

/// Exposes the active [BackendWebSocketSession] when connected, or `null`.

final class BackendWebSocketSessionProvider
    extends
        $FunctionalProvider<
          BackendWebSocketSession?,
          BackendWebSocketSession?,
          BackendWebSocketSession?
        >
    with $Provider<BackendWebSocketSession?> {
  /// Exposes the active [BackendWebSocketSession] when connected, or `null`.
  BackendWebSocketSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendWebSocketSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendWebSocketSessionHash();

  @$internal
  @override
  $ProviderElement<BackendWebSocketSession?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackendWebSocketSession? create(Ref ref) {
    return backendWebSocketSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendWebSocketSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendWebSocketSession?>(value),
    );
  }
}

String _$backendWebSocketSessionHash() =>
    r'41479980d1f359a797b4f54aac1473a638a75a9a';

/// Broadcast stream of post-handshake [WsEnvelope] messages from the backend.

@ProviderFor(backendWsMessages)
final backendWsMessagesProvider = BackendWsMessagesProvider._();

/// Broadcast stream of post-handshake [WsEnvelope] messages from the backend.

final class BackendWsMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<WsEnvelope>,
          WsEnvelope,
          Stream<WsEnvelope>
        >
    with $FutureModifier<WsEnvelope>, $StreamProvider<WsEnvelope> {
  /// Broadcast stream of post-handshake [WsEnvelope] messages from the backend.
  BackendWsMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendWsMessagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendWsMessagesHash();

  @$internal
  @override
  $StreamProviderElement<WsEnvelope> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<WsEnvelope> create(Ref ref) {
    return backendWsMessages(ref);
  }
}

String _$backendWsMessagesHash() => r'5e60cbb816473eb726910935510568f9b99355fb';
