import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Hides the main window to the system tray without exiting.
final class HideWindowToTrayUseCase {
  /// Creates a [HideWindowToTrayUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Hides the main window to the system tray.
  Future<void> call() => _repository.hideToTray();
}
