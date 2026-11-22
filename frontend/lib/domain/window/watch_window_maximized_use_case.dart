import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Observes changes to the main window's maximized state.
final class WatchWindowMaximizedUseCase {
  /// Creates a [WatchWindowMaximizedUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Returns a stream emitting the window's maximized state on change.
  Stream<bool> call() => _repository.watchIsMaximized();
}
