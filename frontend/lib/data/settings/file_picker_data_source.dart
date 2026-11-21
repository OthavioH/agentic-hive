import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_data_source.g.dart';

/// Abstraction over native OS folder and file pickers.
abstract interface class FilePickerDataSource {
  /// Opens a native directory picker and returns the selected path, or `null`
  /// if cancelled.
  Future<String?> pickDirectory({String? initialDirectory});

  /// Opens a native file picker and returns the selected path, or `null` if
  /// cancelled.
  Future<String?> pickFile({String? initialDirectory});
}

/// Default [FilePickerDataSource] backed by `package:file_selector`.
final class FileSelectorDataSource implements FilePickerDataSource {
  /// Creates a [FileSelectorDataSource].
  const new();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) =>
      getDirectoryPath(initialDirectory: initialDirectory);

  @override
  Future<String?> pickFile({String? initialDirectory}) async {
    final file = await openFile(initialDirectory: initialDirectory);
    return file?.path;
  }
}

/// Provides the [FilePickerDataSource].
@riverpod
FilePickerDataSource filePickerDataSource(Ref ref) =>
    const FileSelectorDataSource();
