# copilot-delegate

Faz o Claude Code trabalhar como orquestrador e delegar o trabalho mecânico (boilerplate, testes, refactors
repetitivos, docs, varreduras de código) ao GitHub Copilot CLI, que roda modelos mais baratos como `gpt-6-luna`.
Só um resumo curto volta para o contexto do Claude.

- `bin/cop`: wrapper seguro do `copilot -p` (fica no PATH do Bash do Claude enquanto o plugin está ativo).
- `skills/copilot-delegation`: regras de quando e como delegar, carregadas sob demanda.
- `skills/delegar`: comando `/delegar <tarefa>`.
- `skills/revisar`: comando `/revisar [foco]`, segunda revisão do diff pelo Copilot.
- `agents/copilot-worker`: subagente em Haiku para tarefas com várias rodadas.

Requer o Copilot CLI autenticado (`copilot login`) e os agentes `cop-worker`, `cop-reviewer` e `cop-tester` em `~/.copilot/agents/`
(o `install.sh` na raiz do repositório instala tudo). Guia completo em `docs/GUIA.md`.
