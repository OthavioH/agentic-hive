/// The Agentic Hive local backend.
library;

export 'src/backend.dart';
export 'src/config/app_config.dart';
export 'src/config/config_loader.dart';
export 'src/config/platform_paths.dart';
export 'src/runtime/runtime_mode.dart';
export 'src/server/local_socket.dart'
    show BackendAlreadyRunningException, SocketPathTooLongException;
export 'src/version.dart';
