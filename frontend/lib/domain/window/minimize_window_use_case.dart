import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Minimizes the main desktop window.
final class MinimizeWindowUseCase {
  /// Creates a [MinimizeWindowUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Minimizes the main window.
  Future<void> call() => _repository.minimize();
}
