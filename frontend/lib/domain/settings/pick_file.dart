import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';

/// Prompts the user to pick a local file.
final class PickFile {
  /// Creates a [PickFile] use case.
  const new(this._repository);

  final FilePickerRepository _repository;

  /// Executes the use case.
  Future<String?> call({String? initialDirectory}) =>
      _repository.pickFile(initialDirectory: initialDirectory);
}
