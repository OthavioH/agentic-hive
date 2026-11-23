import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// Updates the OS window title.
final class SetWindowTitleUseCase {
  /// Creates a [SetWindowTitleUseCase].
  const new(this._repository);

  final WindowControlsRepository _repository;

  /// Sets the window title to [title].
  Future<Result<void>> call(String title) => _repository.setTitle(title);
}
