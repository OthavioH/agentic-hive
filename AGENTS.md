# AGENTS.md

Regras do produto inteiro. `frontend/`, `backend/` e `shared/` terão cada um o seu próprio `AGENTS.md`. Quando uma regra de lá conflitar com esta, a da pasta vale para aquela pasta.

Antes de mudar arquitetura, leia as decisões em `docs/adrs/`. Para mudar uma decisão, escreva um ADR novo que substitua o antigo; não edite o antigo para dizer outra coisa. Use os termos de `GLOSSARY.md` no código, na UI e nos documentos.

## Mapa

| Pasta | O que é | Pode depender de |
|---|---|---|
| `frontend/` | App Flutter desktop: editor de grafos, monitor de execuções, aprovações | `shared/` |
| `backend/` | Servidor local Dart (shelf): motor de grafo, nós, harnesses, SQLite, servidor MCP | `shared/` |
| `shared/` | Pacote Dart puro: schema de workflow, tipos de nó, eventos, DTOs | nada do projeto |
| `docs/adrs/` | Decisões de arquitetura numeradas (`0001-slug.md`) | — |

`frontend/` e `backend/` nunca importam um ao outro. Tudo que os dois precisam concordar (formato do workflow, eventos do WebSocket, tipos de nó) mora em `shared/`.

## Divisão de responsabilidades

- O **backend** é a fonte da verdade. Só ele executa processos, mexe em workspaces e grava estado.
- O **frontend** só desenha, edita e envia comandos. Ele nunca roda harnesses nem lê o SQLite diretamente. Uma execução precisa continuar funcionando com o app fechado.

## Abstrações

Cada família de comportamento tem uma abstração base, e cada variação é uma implementação dela. Não espalhe `switch` por tipo pelo código.

- Nós: `Node` → `HarnessNode` (abstrato) → `ClaudeCodeNode`, `CodexNode`, `GeminiCliNode`, `AntigravityNode`, `TerminalHarnessNode`. O mesmo vale para `ValidatorNode`.
- `HarnessNode` define o fluxo comum (preparar workspace, montar prompt, rodar, coletar o resultado pelo contrato). As subclasses implementam só o que muda: montar a invocação e interpretar a saída da CLI.
- Adicionar um harness novo significa criar uma subclasse e registrá-la. Isso não deve exigir mudanças no motor.

## Invariantes

- **Sucesso vem do contrato de resultado** (`report_result` via MCP ou `result.json`). Exit code diferente de zero só indica falha de infraestrutura; exit code zero sem relatório é falha. Ver `docs/adrs/0003-contrato-de-resultado.md`.
- **O produto é genérico.** Nada no motor pode supor que o workspace é código, que existe um repositório git do usuário ou que há testes. Validações específicas de domínio são nós, nunca regras do motor.
- **Prompts vão pelo stdin ou por arquivo**, nunca como argumento de linha de comando (limite de tamanho no Windows).
- **Cancelamento só é reportado como concluído depois de confirmado** que a árvore de processos saiu.
- **O servidor escuta só em `127.0.0.1`**, exige token e confere o header `Origin`.
- **Login dos harnesses é do usuário.** Detecte erro de autenticação e mostre uma mensagem clara; nunca armazene credenciais de harness.

## Convenções

- Windows é a plataforma alvo. Trate caminhos com `package:path` e teste comportamento de processo no Windows.
- Código, identificadores e mensagens de commit em inglês. Documentação e textos da UI em português.
