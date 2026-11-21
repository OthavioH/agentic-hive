import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';

/// Prompts the user to pick a local directory.
final class PickDirectory {
  /// Creates a [PickDirectory] use case.
  const new(this._repository);

  final FilePickerRepository _repository;

  /// Executes the use case.
  Future<String?> call({String? initialDirectory}) =>
      _repository.pickDirectory(initialDirectory: initialDirectory);
}
