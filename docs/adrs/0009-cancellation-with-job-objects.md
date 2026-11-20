---
status: accepted
---

# Cancellation through Job Objects, confirmed before it is reported

On Windows, `Process.kill()` terminates only the parent process, and harnesses spawn child processes. Each harness runs inside a Job Object (through FFI) configured to terminate every process in the job; cancelling means closing the job. As a fallback, we use `taskkill /T /F`. A run is only marked as cancelled after confirming that the tree has exited; otherwise it shows as "cancellation uncertain" in the UI. Silence or a timeout never counts as proof that the process ended, the same rule Orca follows.
