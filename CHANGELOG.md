# Changelog

## 3.0.0 (2026-11-06)
- `cop -W`: tarefas em git worktree isolado, com `cop --apply` / `cop --discard` / `cop --jobs`.
- `cop -r <job>`: retomada da sessão do Copilot (`--session-id` / `--resume`).
- `cop -R reviewer|tester`: papéis com agentes próprios no Copilot.
- Skill `/revisar`.
- Timeout padrão de 540 s, abaixo do limite de 10 min do Bash do Claude Code.

## 2.0.0 (2026-11-06)
- Empacotado como plugin do Claude Code com marketplace local.
- Skills `copilot-delegation` e `/delegar`, subagente `copilot-worker`, agente `cop-worker` no Copilot.
- `install.sh` com `--dry-run`, merge de `settings.json` com backup, testes.

## 1.0.0 (2026-11-06)
- Primeira versão: script `cop`, regras no CLAUDE.md.
