---
status: accepted
---

# Flutter desktop + backend local em Dart, com motor de grafo próprio

O produto é um app Flutter desktop que conversa com um servidor local em Dart (shelf), que roda em segundo plano. Escolhemos Dart em vez de Python + LangGraph porque os nós não chamam LLMs diretamente (ver ADR 0002). O que usaríamos do LangGraph (estado compartilhado, arestas condicionais, ciclos, checkpoints, interrupções) é pequeno o bastante para escrever em Dart. Em troca, temos uma linguagem só, tipos compartilhados entre frontend e backend (`shared/`) e um backend distribuído como um `.exe` único (`dart compile exe`), sem empacotar Python no Windows.

## Opções consideradas

- **Python + LangGraph:** ecossistema pronto, mas duplica os modelos em duas linguagens e complica a distribuição no Windows.
- **Motor dentro do próprio app Flutter:** mais simples, mas as execuções morreriam ao fechar o app.

## Consequências

- Recursos do LangGraph que não vêm de graça (tracing, "time travel", fan-out paralelo) precisam ser construídos sobre o log de eventos e `Future.wait`.
- No início, o backend roda como processo em segundo plano iniciado pelo app, com ícone na bandeja. Um serviço do Windows rodaria em outra sessão e não enxergaria o login dos harnesses do usuário.
