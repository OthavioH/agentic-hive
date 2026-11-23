---
status: accepted
---

# The app owns the tray icon; the backend is an independent process

Amends ADR 0001, which gave the tray icon to the backend. A Dart CLI executable has no practical way to show a tray icon, so the Flutter app owns it. The backend stays an independent process: the app starts it when no live socket answers in the data folder, and it keeps running after the app closes so runs continue. Closing the window hides the app to the tray. Quitting from the tray closes only the app; the backend stops on its own only when no run is active.

## Consequences

- The app must handle finding an already running backend (through `server.json` and the socket) as the normal case, not an error.
- Stopping the backend while runs are active needs an explicit user action.
