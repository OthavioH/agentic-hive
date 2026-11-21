/// Validates whether a file path points to an existing executable file.
///
/// OS-specific permission checks live behind this interface; callers never
/// branch on `Platform.operatingSystem` inline.
abstract interface class ExecutableValidator {
  /// Returns `true` if [path] exists, is a regular file (or resolves to
  /// one), and is executable on the current platform.
  Future<bool> isExecutable(String path);
}
