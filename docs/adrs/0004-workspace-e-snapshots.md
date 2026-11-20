---
status: accepted
---

# Workspace por execução, com snapshots em um git sombra

Voltar um passo no grafo não desfaz o que o agente mudou nos arquivos. Cada execução tem um workspace (uma pasta qualquer), e antes de cada nó o backend tira um snapshot dela num repositório git sombra que fica fora da pasta do usuário (`--git-dir` próprio, `--work-tree` apontando para o workspace). Assim o rollback funciona para qualquer tipo de arquivo, não só código, e não interfere no git do usuário. Quando o workspace já é um repositório do usuário e a execução precisa de isolamento, usamos uma git worktree separada.

## Opções consideradas

- **Exigir que o workspace seja um repositório git:** limitaria o produto a desenvolvimento de software.
- **Copiar a pasta inteira a cada nó:** simples, mas lento e caro em disco para pastas grandes.

## Consequências

- Git passa a ser requisito de instalação, mesmo para quem não programa.
- Arquivos muito grandes ou binários podem deixar os snapshots lentos; vamos precisar de regras de exclusão por workspace.
