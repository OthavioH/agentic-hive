/// Whether the backend runs from source or as a compiled executable.
enum RuntimeMode {
  /// `dart run` (JIT). Logs at `FINE`.
  development,

  /// A `dart compile exe` build (AOT). Logs at `INFO`.
  production;

  /// The mode of the current process. `dart.vm.product` is only true in
  /// AOT-compiled executables.
  static const RuntimeMode current = bool.fromEnvironment('dart.vm.product')
      ? production
      : development;
}
