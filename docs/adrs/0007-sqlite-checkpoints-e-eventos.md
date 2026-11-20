---
status: accepted
---

# Estado em SQLite: checkpoint por nó e log de eventos

O backend grava um checkpoint do estado do grafo no SQLite ao fim de cada nó, e todos os eventos da execução num log append-only. Uma execução pausada (aprovação humana, `ask_human`) não mantém nada em memória: ela é retomada a partir do checkpoint. O log de eventos alimenta o histórico na UI e substitui o tracing que o LangGraph teria. Postgres (usado pelo LangConfig) foi descartado por exigir um servidor separado num app desktop.

## Consequências

- O checkpoint é por nó. Um nó interrompido no meio (crash, desligamento) é refeito do início, a partir do snapshot do workspace (ADR 0004).
- O retry acontece na mesma tarefa, com limite por aresta (`maxRetries`) e um circuit breaker global para falhas de infraestrutura repetidas, como no Orca.
