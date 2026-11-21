import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/presentation/error/pages/route_error_page.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router_provider.g.dart';

final class _BackendConnectionRefreshNotifier extends ChangeNotifier {
  new(this._connectionState);

  BackendConnectionState _connectionState;
  String? rememberedLocation;

  BackendConnectionState get connectionState => _connectionState;

  void updateConnectionState(BackendConnectionState next) {
    if (_connectionState.isConnected == next.isConnected) return;
    _connectionState = next;
    notifyListeners();
  }

  String consumeRememberedLocation({required String fallback}) {
    final target = rememberedLocation ?? fallback;
    rememberedLocation = null;
    return target;
  }
}

/// Provides the application's [GoRouter] instance, reacting to
/// [backendConnectionProvider] via a `refreshListenable`.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final notifier = _BackendConnectionRefreshNotifier(
    ref.read(backendConnectionProvider),
  );
  ref
    ..listen<BackendConnectionState>(
      backendConnectionProvider,
      (_, next) => notifier.updateConnectionState(next),
    )
    ..onDispose(notifier.dispose);

  final router = GoRouter(
    initialLocation: OverviewRoute.path,
    routes: $appRoutes,
    refreshListenable: notifier,
    redirect: (context, state) {
      final connection = notifier.connectionState;
      final isConnectingRoute = state.matchedLocation == ConnectingRoute.path;

      if (!connection.isConnected) {
        if (!isConnectingRoute) {
          final target = state.uri.toString();
          notifier.rememberedLocation = target.isNotEmpty && target != '/'
              ? target
              : OverviewRoute.path;
          return ConnectingRoute.path;
        }
        return null;
      }

      if (isConnectingRoute) {
        return notifier.consumeRememberedLocation(fallback: OverviewRoute.path);
      }

      return null;
    },
    errorBuilder: (context, state) => const RouteErrorPage(),
  );

  ref.onDispose(router.dispose);
  return router;
}
