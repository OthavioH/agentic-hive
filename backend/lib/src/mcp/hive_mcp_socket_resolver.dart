import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';

/// Finds the backend socket for `hive-mcp`: an explicit path, else the socket
/// of the configuration the backend itself would load.
final class HiveMcpSocketResolver {
  /// Creates a resolver that loads the configuration with the given loader.
  new({required this._loadConfig});

  final Future<AppConfig> Function() _loadConfig;

  /// Returns [explicitSocket] when set, else the configured socket path.
  ///
  /// Never throws: discovery problems become a [FailureResult].
  Future<Result<String>> resolve({String? explicitSocket}) async {
    if (explicitSocket != null) {
      return Success(explicitSocket);
    }
    try {
      return Success((await _loadConfig()).socketPath);
    } on Object catch (error) {
      return FailureResult(
        UnexpectedFailure('Cannot find the backend socket: $error'),
      );
    }
  }
}
