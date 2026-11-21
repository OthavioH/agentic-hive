/// Resolves a CLI executable name on the system `PATH`.
///
/// OS-specific implementations (`where` on Windows, `which` on POSIX) live in
/// `data/harnesses/` per ADR 0012.
abstract interface class ExecutableLocator {
  /// Returns the resolved executable path on `PATH`, or `null` if not found.
  Future<String?> locate(String executableName);
}
