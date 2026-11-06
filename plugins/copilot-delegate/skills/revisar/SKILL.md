---
name: revisar
description: Pede ao Copilot uma revisão barata do diff atual (ou de um job em worktree) e resume os achados.
argument-hint: [foco da revisão | job]
disable-model-invocation: true
allowed-tools: Bash(cop *) Bash(git diff *) Bash(git status *)
---

Foco/alvo informado: $ARGUMENTS

1. Se o argumento for um id de job com worktree (`cop --jobs`), rode `cop -R reviewer -C <worktree do job> "<foco>"`.
   Senão, rode `cop -R reviewer "<foco ou 'revisão geral'>"` no diretório atual. Use timeout 600000 no Bash.
2. Para cada achado [alta] ou [média], abra só o trecho citado (arquivo:linha) e confirme se é real.
3. Responda em até 10 linhas: veredito, achados confirmados (arquivo:linha), achados descartados e por quê.
   Não corrija nada sem o usuário pedir.
