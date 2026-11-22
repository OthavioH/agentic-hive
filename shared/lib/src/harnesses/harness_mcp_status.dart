import 'package:json_annotation/json_annotation.dart';

/// Installation status of the Hive MCP server inside a CLI harness.
enum HarnessMcpStatus {
  /// The Hive MCP server is installed and points to the current command.
  @JsonValue('installed')
  installed,

  /// The Hive MCP server is not configured in the harness.
  @JsonValue('not_installed')
  notInstalled,

  /// An entry exists, but its launch command does not match the current build.
  @JsonValue('outdated')
  outdated,

  /// This harness does not support installing the Hive MCP server.
  @JsonValue('unsupported')
  unsupported,

  /// Detection failed, timed out, or produced unparsable output.
  @JsonValue('unknown')
  unknown,
}
