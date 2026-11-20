---
status: accepted
---

# Nodes form a hierarchy of abstractions, with one subclass per harness

Every node extends `Node`. Agent nodes extend the abstract `HarnessNode`, which implements the common flow (prepare the workspace, build the prompt from the agent and the context, run, collect the result through the contract) as a template method. Each harness is a subclass (`ClaudeCodeNode`, `CodexNode`, `GeminiCliNode`, `AntigravityNode`, `TerminalHarnessNode`) that implements only what varies: building the invocation and interpreting the output. Validators follow the same pattern with `ValidatorNode`. Node types live in a registry, and the engine never switches on type.

We chose this so that adding a new harness means creating a class and registering it, without touching the engine, and so that differences between CLIs stay contained in one place.
