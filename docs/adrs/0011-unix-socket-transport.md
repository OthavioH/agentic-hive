---
status: accepted
---

# The backend listens only on a Unix domain socket

Supersedes ADR 0008.

The backend serves HTTP and WebSocket on a Unix domain socket at `<data dir>/backend.sock` and opens no TCP port. File permissions are the authentication: the data folder is owner-only (`0700` on Linux and macOS; the user profile ACL on Windows), so only processes of the same OS user can connect. Browsers cannot reach a Unix socket, which removes the "malicious website calls localhost" attack at the transport level. Requests carrying an `Origin` header are still rejected as a free extra layer. `server.json` in the data folder tells the frontend the socket path.

We measured the cost on Windows with Dart 3.14: the socket was faster than TCP loopback (about 200 µs vs 280–510 µs per HTTP request), and Windows 10+, Linux and macOS all support it.

## Considered options

- **TCP on `127.0.0.1` with `Origin`/`Host` checks only:** simple, but any other OS user on the same machine could drive the backend with the owner's harnesses.
- **TCP plus a per-install token file, or plus JWT sessions:** works, but adds a secret to store, rotate and keep out of logs, for no gain over file permissions.
- **Checking the connecting process's OS user through native APIs:** robust, but needs FFI code per operating system.

## Consequences

- No login, token or session exists. If remote access (for example, a mobile companion) is ever added, it gets its own authenticated transport.
- Clients need a socket-aware HTTP client (a `connectionFactory` in `dart:io`). For manual testing: `curl --unix-socket <path> http://localhost/health`.
- Socket paths are limited to 103 bytes on macOS and 107 on Linux and Windows; the backend refuses to start with a longer path.
- Only one backend can serve a data folder: on start, a socket file that still answers means another backend is running.
