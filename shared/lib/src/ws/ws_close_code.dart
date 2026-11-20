/// WebSocket close codes the backend sends.
///
/// Application codes must be in the 4000–4999 range (RFC 6455, section 7.4.2).
abstract final class WsCloseCode {
  /// The backend is stopping. Clients should reconnect once it is back.
  static const serverShuttingDown = 4001;
}
