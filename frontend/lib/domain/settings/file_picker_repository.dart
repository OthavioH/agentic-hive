/// Domain abstraction for selecting local directories and files via the
/// native operating system picker.
abstract interface class FilePickerRepository {
  /// Prompts the user to select a directory, returning its path or `null` if
  /// cancelled.
  Future<String?> pickDirectory({String? initialDirectory});

  /// Prompts the user to select a file, returning its path or `null` if
  /// cancelled.
  Future<String?> pickFile({String? initialDirectory});
}
