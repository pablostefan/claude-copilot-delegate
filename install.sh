#!/usr/bin/env bash
# Instala o copilot-delegate. Tudo com backup; settings.json só muda com --settings.
#
#   ./install.sh                 plugin + agente do Copilot + linhas no CLAUDE.md
#   ./install.sh --settings      também mescla settings/settings-economia.json no ~/.claude/settings.json
#   ./install.sh --explore       também instala o Explore em Haiku (~/.claude/agents/Explore.md)
#   ./install.sh --dry-run       mostra o que faria
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
DO_SETTINGS=0 DO_EXPLORE=0 DRY=0
for a in "$@"; do
  case "$a" in
    --settings) DO_SETTINGS=1 ;;
    --explore) DO_EXPLORE=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "opção desconhecida: $a" >&2; exit 2 ;;
  esac
done

run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
backup() { [ -e "$1" ] && run cp "$1" "$1.bak-$TS" && echo "  backup: $1.bak-$TS" || true; }
ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

echo "== Pré-requisitos"
command -v claude >/dev/null || { echo "claude não encontrado"; exit 1; }
command -v copilot >/dev/null || { echo "copilot não encontrado (brew install copilot-cli)"; exit 1; }
ok "claude $(claude --version 2>/dev/null | head -1) · $(copilot --version 2>/dev/null | head -1)"

echo "== Plugin do Claude Code"
run claude plugin validate "$ROOT"
run claude plugin marketplace add "$ROOT" || run claude plugin marketplace update claude-copilot-delegate
run claude plugin install copilot-delegate@claude-copilot-delegate
ok "plugin copilot-delegate instalado (comando cop, skills copilot-delegation, /delegar e /revisar, agente copilot-worker)"

echo "== Agente do Copilot"
CP_HOME="${COPILOT_HOME:-$HOME/.copilot}"
run mkdir -p "$CP_HOME/agents"
for a in cop-worker cop-reviewer cop-tester; do
  backup "$CP_HOME/agents/$a.agent.md"
  run cp "$ROOT/copilot/agents/$a.agent.md" "$CP_HOME/agents/"
  ok "$CP_HOME/agents/$a.agent.md"
done

echo "== CLAUDE.md global"
if grep -q '# Orquestração e economia' "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
  ok "já tem as regras de orquestração"
else
  backup "$HOME/.claude/CLAUDE.md"
  if [ "$DRY" = 1 ]; then echo "[dry-run] anexar settings/CLAUDE-snippet.md"; else cat "$ROOT/settings/CLAUDE-snippet.md" >>"$HOME/.claude/CLAUDE.md"; fi
  ok "regras anexadas ao ~/.claude/CLAUDE.md"
fi

if [ "$DO_SETTINGS" = 1 ]; then
  echo "== settings.json"
  if [ "$DRY" = 1 ]; then
    python3 "$ROOT/settings/merge_settings.py" "$HOME/.claude/settings.json" "$ROOT/settings/settings-economia.json" --dry-run
  else
    python3 "$ROOT/settings/merge_settings.py" "$HOME/.claude/settings.json" "$ROOT/settings/settings-economia.json"
  fi
else
  warn "settings.json não foi alterado (rode com --settings, ou veja: python3 settings/merge_settings.py ~/.claude/settings.json settings/settings-economia.json --dry-run)"
fi

if [ "$DO_EXPLORE" = 1 ]; then
  echo "== Explore em Haiku"
  run mkdir -p "$HOME/.claude/agents"
  backup "$HOME/.claude/agents/Explore.md"
  run cp "$ROOT/settings/agents/Explore.md" "$HOME/.claude/agents/"
  ok "~/.claude/agents/Explore.md"
fi

echo
echo "Teste rápido (num projeto):  cop \"liste os 5 maiores arquivos .dart e diga em 1 linha o que cada um faz\""
echo "No Claude: /reload-plugins (ou abra uma sessão nova) e peça \"/delegar <tarefa>\"."
