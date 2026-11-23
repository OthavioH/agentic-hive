import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Toggles the main window between maximized and restored states.
final class ToggleMaximizeWindowUseCase {
  /// Creates a [ToggleMaximizeWindowUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Toggles the maximized state.
  Future<void> call() => _repository.toggleMaximize();
}
