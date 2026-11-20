---
status: accepted
---

# Orquestrar os harnesses do usuário em vez de chamar APIs de LLM

Os nós de agente executam CLIs que o usuário já instalou e logou (Claude Code, Codex, Gemini CLI, Antigravity CLI), em vez de chamar APIs de modelos. Assim o usuário usa a assinatura e a configuração que já tem, e o Agentic Hive não guarda chaves nem credenciais. Login, cota e configuração de cada harness são responsabilidade do usuário; o backend só detecta o erro de autenticação e o mostra de forma clara.

## Consequências

- O produto depende de flags e formatos de saída que mudam entre versões das CLIs. Os adapters ficam finos e isolados, um por harness (ver ADR 0006).
- Rate limit e cota estourada são um tipo de falha à parte, diferente de falha da tarefa.
