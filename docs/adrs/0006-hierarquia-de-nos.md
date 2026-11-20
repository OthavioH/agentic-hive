---
status: accepted
---

# Nós são uma hierarquia de abstrações, com uma subclasse por harness

Todo nó estende `Node`. Os nós de agente estendem a classe abstrata `HarnessNode`, que implementa o fluxo comum (preparar o workspace, montar o prompt a partir do agente e do contexto, executar, coletar o resultado pelo contrato) como um template method. Cada harness é uma subclasse (`ClaudeCodeNode`, `CodexNode`, `GeminiCliNode`, `AntigravityNode`, `TerminalHarnessNode`) que implementa só o que muda: montar a invocação e interpretar a saída. Validadores seguem o mesmo padrão com `ValidatorNode`. Os tipos de nó ficam num registro, e o motor nunca faz `switch` por tipo.

Escolhemos isso para que adicionar um harness novo seja criar uma classe e registrá-la, sem tocar no motor, e para que as diferenças entre CLIs fiquem contidas num lugar só.
