import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Starts an interactive drag of the main desktop window.
final class StartWindowDragUseCase {
  /// Creates a [StartWindowDragUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Begins dragging the main window.
  Future<void> call() => _repository.startDragging();
}
