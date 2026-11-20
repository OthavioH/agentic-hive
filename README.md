# Agentic Hive

Orquestrador visual de agentes de IA para Windows. Você monta um workflow em grafo e cada nó roda usando os harnesses que você já tem instalados e logados: Claude Code, Codex, Gemini CLI, Antigravity CLI. O workflow pode continuar rodando sozinho em segundo plano.

> **Status:** em planejamento. Ainda não há código. As decisões de arquitetura estão em [`docs/adrs/`](docs/adrs/).

## Por que existe

Frameworks como o LangGraph resolvem orquestração de agentes, mas exigem escrever e rodar código para cada tarefa, e chamam as APIs dos modelos diretamente (com chave e cobrança próprias). O Agentic Hive aproveita o que o usuário já paga e configura: as próprias CLIs de agentes. O app só desenha o trilho entre elas.

O produto não se limita a desenvolvimento de software. Um workflow pode pesquisar, escrever, revisar documentos ou processar arquivos. Qualquer tarefa que um agente de terminal consiga fazer numa pasta serve.

## Como funciona

```
┌──────────────────────┐   HTTP + WebSocket    ┌──────────────────────────────┐
│  Frontend (Flutter)  │ ◄──────────────────►  │  Backend (Dart + shelf)      │
│  editor de grafos,   │   127.0.0.1 + token   │  motor de grafo, checkpoints │
│  monitor, aprovações │                       │  (SQLite), servidor MCP      │
└──────────────────────┘                       └──────────────┬───────────────┘
                                                              │ Process / PTY
                                          ┌───────────────────┼───────────────────┐
                                          ▼                   ▼                   ▼
                                     claude -p           codex exec            agy -p   ...
                                          └──────── workspace da execução ────────┘
```

1. **Agentes** são arquivos `.md` (frontmatter + prompt) numa pasta de agentes do usuário.
2. **Workflows** são grafos: nós ligados por arestas `onSuccess` / `onFailure`, que podem formar ciclos com limite de tentativas.
3. Uma **execução** (run) ganha um **workspace** próprio. Antes de cada nó, o backend tira um snapshot da pasta para poder voltar atrás.
4. Cada agente informa o resultado pelo **contrato de resultado**: chama a ferramenta MCP `report_result` do backend ou grava um `result.json`. O exit code só serve para detectar falhas de infraestrutura.
5. Nós validadores decidem a rota: comando, juiz LLM com resposta em JSON, checagem de arquivo ou aprovação humana.
6. Nós humanos e a ferramenta `ask_human` pausam a execução. O estado fica salvo no SQLite e a execução retoma quando você responde no app.

## Tipos de nó

O código segue uma hierarquia de abstrações. Cada harness é uma subclasse de `HarnessNode`:

```
Node
├── HarnessNode (abstrato)
│   ├── ClaudeCodeNode       claude -p --output-format stream-json
│   ├── CodexNode            codex exec
│   ├── GeminiCliNode        gemini -p
│   ├── AntigravityNode      agy -p --output-format stream-json
│   └── TerminalHarnessNode  qualquer CLI, via pseudo-terminal (PTY)
├── CommandNode              roda um comando ou script
├── ValidatorNode (abstrato)
│   ├── CommandValidatorNode
│   ├── LlmJudgeNode
│   └── FileCheckNode
└── HumanApprovalNode
```

As flags exatas de cada CLI precisam ser confirmadas na implementação de cada adapter. Elas mudam entre versões.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `frontend/` | App Flutter desktop (Windows) |
| `backend/` | Servidor local em Dart (shelf): motor, harnesses, persistência |
| `shared/` | Pacote Dart com o schema de workflow, eventos e modelos usados pelos dois lados |
| `docs/adrs/` | Registros de decisões de arquitetura |

## Requisitos (previstos)

- Windows 10/11
- Pelo menos um harness instalado e logado pelo próprio usuário (o Agentic Hive não gerencia login)
- Git, usado internamente para os snapshots de workspace

## Primeiro marco

Um spike só do backend, sem UI, que prove os pontos de maior risco no Windows:

- [ ] Ler um workflow em JSON e rodar coder → validador → revisor, voltando ao coder em caso de reprovação
- [ ] `ClaudeCodeNode` headless, com o prompt enviado pelo stdin
- [ ] Contrato de resultado via MCP e `result.json`
- [ ] Checkpoint em SQLite e snapshot do workspace por nó
- [ ] Pausa num `HumanApprovalNode` e retomada por HTTP
- [ ] Cancelamento que encerra toda a árvore de processos

## Documentação

- [`AGENTS.md`](AGENTS.md): regras gerais para quem (humano ou agente) mexe no código
- [`GLOSSARY.md`](GLOSSARY.md): vocabulário do domínio
- [`docs/adrs/`](docs/adrs/): decisões de arquitetura e seus motivos
