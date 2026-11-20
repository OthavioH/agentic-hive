---
status: accepted
---

# O sucesso de um nó vem do contrato de resultado, não do exit code

Harnesses saem com código 0 mesmo quando o agente desistiu ou fez errado. Por isso, cada nó de agente precisa informar o resultado explicitamente: pela ferramenta `report_result(status, output, artifacts)` do servidor MCP local do backend, ou, para harnesses sem MCP, gravando um `result.json` num caminho que o prompt informa. Exit code diferente de zero indica falha de infraestrutura. Exit code zero sem relatório também é falha. O mesmo servidor MCP oferece `ask_human(question)`, que pausa a execução até o usuário responder.

A ideia vem do Orca, onde o agente chama `worker_done` e `ask` em vez de o orquestrador adivinhar pelo terminal.

## Opções consideradas

- **Só exit code:** não distingue "rodou" de "deu certo".
- **Interpretar a saída de texto do agente:** frágil e diferente para cada harness.
