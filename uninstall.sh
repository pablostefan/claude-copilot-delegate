#!/usr/bin/env bash
# Remove o plugin e o agente do Copilot. settings.json e CLAUDE.md têm backups (*.bak-*) para restaurar à mão.
set -uo pipefail
claude plugin uninstall copilot-delegate@claude-copilot-delegate
claude plugin marketplace remove claude-copilot-delegate
for a in cop-worker cop-reviewer cop-tester; do rm -f "${COPILOT_HOME:-$HOME/.copilot}/agents/$a.agent.md"; done
echo "Removido. Para desfazer CLAUDE.md/settings.json/Explore.md, restaure os arquivos .bak-<data> em ~/.claude/."
