---
status: accepted
---

# The app draws its own title bar on Windows and Linux

The native title bar (the OS strip showing "frontend" and the system caption buttons) clashed with the app's theme. The app now removes the native frame on Windows and Linux and draws a dedicated full-width strip at the top of the window. The strip is empty apart from the caption buttons (minimize, maximize/restore, close) on the right, in Windows order. The empty area is for dragging. Double-click toggles maximize, and right-click opens the system menu. The strip uses the app background with no divider, and resizing from the window edges and drag-to-snap still work. On macOS the title is hidden but the native traffic-light buttons stay, following platform convention. The difference lives behind the per-OS window abstraction (ADR 0012).

The title bar and caption buttons are a purely visual `design_system` component that takes callbacks and the maximized state, and it knows nothing about the windowing plugin (ADR 0018). The app wires it to its window service and shows it on every screen, including screens outside the shell, such as connecting and error.

The close button keeps the meaning set in ADR 0016: it hides the app to the tray, and quitting stays in the tray menu.

The app is named **Agentic Hive** everywhere the user sees it (window title, `ProductName`/`FileDescription`, GTK title). The technical identifiers are `agentic_hive` (binary name) and `dev.othavioh.agentic_hive` (Linux application ID). The Dart package `agentic_hive_frontend` keeps its internal name.

The app icon on every OS is the Hive hex mark. It is generated from the same geometry and color tokens as `HiveHexMark` by the design system's icon generator, the one that already produces the tray icons, so the logo has a single source. On Windows and Linux it is the hexagon on a transparent background. On macOS the hexagon sits on a dark rounded-square tile, following platform convention.

## Consequences

- We lose the Windows 11 Snap Layouts flyout that appears on hovering the native maximize button; Win+Z still works. Getting it back would need Windows-only native code in the runner.
- On tiling Linux window managers (i3, Hyprland) the minimize and maximize buttons can do nothing. We accept this rather than detect the window manager.
- Renaming the binary changes the executable path. Nothing in the repo referenced `frontend.exe` when this was decided.
