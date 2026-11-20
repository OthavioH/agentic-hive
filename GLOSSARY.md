# Agentic Hive

Orquestrador visual que encadeia agentes de IA de terminal (harnesses) num grafo e roda o resultado localmente.

## Definições

**Agente**:
Um arquivo `.md` com frontmatter e prompt que descreve um papel (por exemplo, "revisor"). Não sabe em qual harness vai rodar.
_Evite_: bot, persona, assistente

**Harness**:
Uma CLI de agente instalada pelo usuário que executa o trabalho de um agente, como Claude Code ou Antigravity CLI.
_Evite_: provider, modelo, engine

**Workflow**:
Um grafo de nós e arestas salvo pelo usuário. É a receita, não a execução.
_Evite_: pipeline, flow, grafo (quando se refere ao artefato salvo)

**Nó**:
Um passo de um workflow. Tem um tipo (harness, comando, validador, aprovação humana) e uma ou mais saídas.
_Evite_: step, etapa, task

**Aresta**:
Uma ligação entre nós, rotulada pela saída que a ativa (`onSuccess`, `onFailure` ou um rótulo do validador).
_Evite_: link, transição

## Execução

**Execução**:
Uma rodada de um workflow, com estado, histórico e workspace próprios.
_Evite_: run (na UI), job, instância

**Workspace**:
A pasta onde os nós de uma execução trabalham. Pode ser qualquer pasta, não necessariamente um repositório.
_Evite_: projeto, repo, sandbox

**Snapshot**:
O estado salvo dos arquivos do workspace antes de um nó, usado para voltar atrás.
_Evite_: backup, commit

**Checkpoint**:
O estado salvo do grafo (posição, tentativas, saídas dos nós) ao fim de cada nó.
_Evite_: save, snapshot (que é dos arquivos)

**Contrato de resultado**:
A forma como um agente informa ao backend que terminou e com qual status: a ferramenta MCP `report_result` ou o arquivo `result.json`.
_Evite_: retorno, exit status

**Pausa**:
O estado de uma execução que espera uma resposta humana, por um nó de aprovação ou por `ask_human`.
_Evite_: bloqueio, espera
