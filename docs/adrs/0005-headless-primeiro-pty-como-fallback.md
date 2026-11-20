---
status: accepted
---

# Harnesses rodam em modo headless; PTY é o fallback genérico

Por padrão, cada harness roda no seu modo headless (`claude -p`, `codex exec`, `gemini -p`, `agy -p`), com saída em JSON ou stream-JSON quando a CLI oferece. Isso dá eventos estruturados para a UI. Para CLIs sem modo headless, o `TerminalHarnessNode` roda o programa num pseudo-terminal (ConPTY), como o Orca faz. Nesse caso o fim é detectado pelo contrato de resultado (ADR 0003), e o usuário pode ver e assumir o terminal.

## Consequências

- O PTY genérico é mais difícil de testar e de interpretar. Ele fica para depois do primeiro marco.
- Em qualquer modo, o prompt vai pelo stdin ou por arquivo, nunca como argumento, por causa do limite de tamanho da linha de comando no Windows.
