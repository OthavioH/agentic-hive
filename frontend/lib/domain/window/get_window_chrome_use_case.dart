import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Reads the platform window chrome capabilities and initial maximized state.
final class GetWindowChromeUseCase {
  /// Creates a [GetWindowChromeUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Returns the current [WindowChromeConfig].
  WindowChromeConfig call() => (
    hasCustomTitleBar: _repository.hasCustomTitleBar,
    showSystemMenuOnRelease: _repository.showSystemMenuOnRelease,
    isMaximized: _repository.isMaximized,
  );
}
