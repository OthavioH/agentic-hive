/// Version of the WebSocket message protocol.
///
/// Increase it on any breaking change to [WsMessageType] payloads.
const wsProtocolVersion = 1;

/// Every message `type` the WebSocket protocol knows.
abstract final class WsMessageType {
  /// Server → client, sent once right after the connection opens.
  static const serverHello = 'server.hello';

  /// Server → client, answers a message the server could not handle.
  static const error = 'error';

  /// Server → client, broadcast when an agent `.md` file changes on disk.
  static const agentsChanged = 'agents.changed';
}
