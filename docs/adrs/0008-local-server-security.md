---
status: superseded by ADR-0011
---

# Local server on loopback only, with a token and an Origin check

The backend runs arbitrary commands, and any website open in the browser can send requests to `localhost`. So the server listens only on `127.0.0.1`, requires a token generated at install time (the frontend reads it from a local user file), and rejects requests with an unexpected `Origin`. Routes that run processes stay disabled until the user enables them, in the same "closed by default" spirit as LangConfig.
