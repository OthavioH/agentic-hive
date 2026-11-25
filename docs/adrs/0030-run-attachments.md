---
status: proposed
---

# Run attachments live in the run data folder and end with the run

Users want to give a run images (screenshots, mockups) with the Run input, pasted or dropped in the Start Run dialog. The images must reach the agents only while the run lives and must never be committed. We store them in the run's own data folder, outside every workspace, and delete them when the run ends. This extends ADR 0022: the Run input itself stays free text, and its propagation rules stay in force.

## Decisions

- **Location.** `<app data>/runs/<run id>/attachments/`, a sibling of the run's results folder. Files are written only when the run starts, after validation, under generated names (`1.png`, `2.jpg`, …); the user's file name is kept only as display metadata.
- **Formats and limits.** PNG, JPEG, WebP and GIF, checked by file signature, not extension. At most 10 images per run, 10 MiB each, 25 MiB in total. No downscaling. A run may have images and no text.
- **Transport.** Images travel inline (base64, with file name and MIME type) in the start-run request. There is no separate upload, so an abandoned dialog leaves nothing behind. The backend validates everything before it creates a worktree or writes a file.
- **Delivery to agents.** `HarnessNode` adds a `## Run attachments` section listing each absolute path and telling the agent to open the files with its file-reading tool, and grants read access to the folder the same way as the results folder. Every node of the run sees the list, as with the Run input (ADR 0022); `inputScope` still applies as guidance. Fan-out child runs do not inherit the parent's attachments (ADR 0029).
- **End of life.** Files are deleted when the run reaches `succeeded`, `failed` or `cancelled`, and when the run is deleted. They are kept while the run is `running`, `paused`, `cancelling`, `cancellationUncertain` (processes may still read them) or `interrupted` (it can be resumed). At startup the backend deletes leftover attachment folders of runs already in an ended status.
- **History.** The run keeps each attachment's display name, MIME type and size permanently. The run detail lists them and marks them removed once the run has ended; no thumbnails.

## Considered options

- **Inside the target folder** (`.agentic-hive/attachments/<run id>/` plus a per-worktree git exclude entry). Rejected: an agent can still commit or move the files, snapshots and rollbacks (ADR 0004) would capture them, and primary-checkout and non-git runs would put them among the user's own files.
- **A separate upload endpoint before the start request.** Rejected: an upload whose dialog is cancelled leaks files and needs its own cleanup.
