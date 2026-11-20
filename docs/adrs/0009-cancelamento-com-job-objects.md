---
status: accepted
---

# Cancelamento via Job Objects, confirmado antes de ser reportado

No Windows, `Process.kill()` encerra só o processo pai, e os harnesses abrem processos filhos. Cada harness roda dentro de um Job Object (via FFI) configurado para encerrar todos os processos do job; cancelar é fechar o job. Como fallback, usamos `taskkill /T /F`. A execução só é marcada como cancelada depois de confirmar que a árvore saiu; caso contrário, fica como "cancelamento incerto" na UI. Silêncio ou timeout nunca contam como prova de que o processo terminou, a mesma regra do Orca.
