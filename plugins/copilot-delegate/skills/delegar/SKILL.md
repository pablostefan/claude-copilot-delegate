---
name: delegar
description: Delega explicitamente uma tarefa ao Copilot CLI e revisa o resultado.
argument-hint: <o que precisa ser feito>
disable-model-invocation: true
allowed-tools: Bash(cop *) Bash(git diff *) Bash(git status *) Grep Glob
---

Tarefa: $ARGUMENTS

1. Descubra só o necessário para a spec com Grep/Glob (caminhos e um arquivo de exemplo do padrão). Não leia arquivos inteiros.
2. Monte a spec no formato da skill `copilot-delegation` (Objetivo, Arquivos, Siga o padrão de, Regras, Aceite, Verificação).
3. Rode `cop -w "<spec>"`. Se for só pergunta, `cop "<pergunta>"`.
4. Revise com `git diff --stat` e rode o comando de verificação.
5. Responda em até 8 linhas: o que mudou, se a verificação passou, o que ficou pendente.
