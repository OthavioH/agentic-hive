---
status: accepted
---

# The terminal emulator is `xterm2`, with clipboard writes and read-only pointer input turned off

`HiveTerminalView` moves from `xterm` 4.0.0 (last release 2024-02) to `xterm2` 5.5.0, the maintained fork, mainly for desktop IME and dead-key support (the ABNT2 case from #248) and Windows ConPTY reflow. `xterm2` adds behavior that 4.0.0 never had, and harness output is untrusted, so we turn the risky parts off instead of taking its defaults. The migration is **not** a security fix: `xterm` 4.0.0 never answered OSC 52 clipboard queries and never wrote the clipboard from terminal output.

## Decisions

- **Containment.** `xterm2` stays imported only in `design_system/lib/src/components/hive_terminal_view.dart`; no `xterm2` type is public.
- **Clipboard.** Terminal output never writes the system clipboard: the view sets its own no-op `onClipboardStore` and disables iTerm2 (OSC 1337) and kitty (OSC 5522) clipboard capture, in every mode, so snapshot replay cannot rewrite the clipboard either. `onClipboardQuery` stays unset, so the PTY app can never read the clipboard. Both are covered by regression tests. Copying a selection and pasting by the user still work.
- **Pointer input.** In `watch` and `ended` mode pointer input to the app is suspended, so the wheel always scrolls the buffer. In `interactive` mode `dragOverridesMouseReporting` is on, so dragging selects text locally as in 4.0.0; clicks and the wheel still reach mouse-reporting apps.
- **Other features stay unwired.** No `onCopy`/`onPaste` hooks, hyperlink taps, URL opening or notifications. Color queries (OSC 10/11) are answered with our theme colors; replies reach the PTY only in `interactive` mode, as all output does.
- **Windows PTY mode.** `Terminal(windowsPtyMode:)` is a constructor argument, so `HiveTerminalController` takes a `windowsPty` flag. The frontend gets it from an OS abstraction (one implementation per OS, ADR 0012), not from the backend: the backend always runs on the same machine (ADR 0011), so no `shared/` or wire change is needed.
- **Lifecycle.** `HiveTerminalController.dispose()` disposes the `Terminal` (it now owns a timer); detaching the view after dispose stays safe.
- **Tests.** View tests for typing, IME composition, clipboard blocking, the pointer policy and dispose run under the Windows, Linux and macOS target platforms, because desktop input now goes through the system input method and the default (Android) test platform would not cover it.
- **Pinning.** `xterm2` is pinned exactly. Its model package `xterm2_core` comes in through a caret range and is pinned only by the committed root `pubspec.lock`; we do not add a direct pin.
- **Rollback.** If IME, dead keys or rendering regress, revert to `xterm` 4.0.0. `hardwareKeyboardOnly: true` is not a fallback: it breaks dead keys.
- **Verification.** A human checks ABNT2 dead keys, AltGr characters and paste on Windows before the work is closed; a failure triggers the rollback. Linux and macOS checks are non-blocking and happen when hardware is available.

## Considered options

- **Keep `xterm` 4.0.0.** Rejected: unmaintained, no desktop IME path.
- **Take `xterm2` defaults.** Rejected: focused views, watch mode included, would let harness output write the clipboard.
- **Allow clipboard writes in `interactive` mode only.** Rejected: the user takes over to type, not to grant the app clipboard access, and nothing in the product needs it.
- **Send the PTY kind from the backend.** Rejected: changes the shared schema to carry a fact the app already knows.
