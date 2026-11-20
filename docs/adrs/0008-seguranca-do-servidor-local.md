---
status: accepted
---

# Servidor local só em loopback, com token e checagem de Origin

O backend executa comandos arbitrários, e qualquer site aberto no navegador consegue fazer requisições para `localhost`. Por isso o servidor escuta só em `127.0.0.1`, exige um token gerado na instalação (o frontend lê de um arquivo local do usuário) e rejeita requisições com `Origin` inesperado. As rotas que executam processos ficam desligadas até o usuário habilitar, no mesmo espírito "fechado por padrão" do LangConfig.
