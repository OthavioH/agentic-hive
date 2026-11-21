import 'package:agentic_hive_frontend/data/settings/file_picker_data_source.dart';
import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_repository_impl.g.dart';

/// [FilePickerRepository] backed by [FilePickerDataSource].
final class FilePickerRepositoryImpl implements FilePickerRepository {
  /// Creates a [FilePickerRepositoryImpl].
  const new(this._dataSource);

  final FilePickerDataSource _dataSource;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) =>
      _dataSource.pickDirectory(initialDirectory: initialDirectory);

  @override
  Future<String?> pickFile({String? initialDirectory}) =>
      _dataSource.pickFile(initialDirectory: initialDirectory);
}

/// Provides the [FilePickerRepository] implementation.
@riverpod
FilePickerRepository filePickerRepository(Ref ref) =>
    FilePickerRepositoryImpl(ref.watch(filePickerDataSourceProvider));
