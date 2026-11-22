import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Opens the native window system menu at a global pointer position.
final class ShowWindowSystemMenuUseCase {
  /// Creates a [ShowWindowSystemMenuUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Shows the system menu at ([x], [y]).
  Future<void> call({required double x, required double y}) =>
      _repository.showSystemMenu(x: x, y: y);
}
