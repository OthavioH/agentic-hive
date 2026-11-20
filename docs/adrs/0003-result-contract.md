---
status: accepted
---

# A node's success comes from the result contract, not the exit code

Harnesses exit with code 0 even when the agent gave up or did the wrong thing. So every agent node must report its result explicitly: through the `report_result(status, output, artifacts)` tool of the backend's local MCP server, or, for harnesses without MCP, by writing a `result.json` at a path given in the prompt. A non-zero exit code signals an infrastructure failure. Exit code zero without a report is also a failure. The same MCP server offers `ask_human(question)`, which pauses the run until the user answers.

The idea comes from Orca, where the agent calls `worker_done` and `ask` instead of the orchestrator guessing from the terminal.

## Considered options

- **Exit code only:** cannot tell "it ran" from "it worked".
- **Parsing the agent's text output:** fragile and different for each harness.
