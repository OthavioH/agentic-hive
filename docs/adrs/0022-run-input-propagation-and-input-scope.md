---
status: proposed
---

# Run input propagation and input scope

The Run input reached only the entry node. A request that mixed work for several nodes was executed entirely by the entry node, and later nodes could not read the parts meant for them. Spec: issue #90.

## Decision

- The engine passes the Run input to every node execution of a run.
- Prompts label it as the user's original request (`## User input`), separate from upstream `Inputs`.
- Harness node configs gain an optional free-text `inputScope`. When set, the prompt tells the node to act only on that part and to leave the rest to other nodes.
- Without `inputScope`, the entry node's prompt is unchanged. A non-entry node receives the full input with a notice that other nodes may handle parts of it and that its own instructions define its task.
- `inputScope` is guidance for the agent, not a security boundary. Permissions stay with ADR 0021.

## Alternatives considered

- **Keep entry-only delivery and let the workflow author forward text through outputs.** Rejected: the first node can drop or rewrite the request, and the author must duplicate text across nodes.
- **A router agent that splits the input per node.** Rejected for v1: it adds a nondeterministic step and a new failure point. It can be built later as a node on top of this decision.
- **Structured, typed run input.** Rejected: the product stays generic (root AGENTS.md); free text fits every domain.

## Consequences

- Node configs in `shared/` gain a field; old workflows stay valid (field optional).
- Every harness prompt can be longer by the size of the Run input, which is already bounded by `maxInputBytes` in `run_service.dart`.
- Scoping relies on the model following instructions, so it reduces but does not eliminate out-of-scope actions. Hard limits belong to the permission policy.
