# Instruções para o Claude Code instalar este kit

Você (Claude Code) está instalando o kit `claude-copilot-delegate` numa máquina nova. Siga os passos em ordem,
mostre ao usuário o resultado de cada um e **peça confirmação antes do passo 6**. Leia `docs/GUIA.md` se
precisar de contexto. Não altere os arquivos do kit, exceto onde o passo 5 manda.

1. **Local fixo**: confirme que esta pasta está num lugar permanente (ex.: `~/GitHub/claude-copilot-delegate`).
   O marketplace do plugin aponta para ela; se ela for movida depois, o plugin quebra.
   Rode `chmod +x install.sh uninstall.sh tests/test_cop.sh plugins/copilot-delegate/bin/cop settings/merge_settings.py`.

2. **Pré-requisitos** (macOS ou Linux; no Windows só funciona dentro do WSL):
   - `claude --version` (2.1.2xx ou mais novo), `git --version`, `python3 --version`.
   - `copilot --version`. Se não existir: `brew install copilot-cli` (macOS) ou `npm install -g @github/copilot`.
   - Login do Copilot: peça ao usuário para rodar `copilot login` no terminal dele, se ainda não fez.

3. **Testes do kit** (não chamam o Copilot de verdade): `bash tests/test_cop.sh`. Precisa terminar com `0 falhas`.

4. **Modelo**: o padrão do kit é `gpt-6-luna`. Peça ao usuário para abrir `copilot`, digitar `/model` e confirmar
   o ID exato do modelo "Luna" (e o do Haiku). Se for diferente, use-o no passo 5.

5. **Ajuste do modelo** (só se o ID do passo 4 for diferente): troque `gpt-6-luna` pelo ID correto na linha
   `MODEL="${COP_MODEL:-gpt-6-luna}"` de `plugins/copilot-delegate/bin/cop`.

6. **Simulação**: rode `./install.sh --dry-run --settings --explore` e mostre ao usuário, em resumo:
   - o que vai para `~/.claude/settings.json` (o script mescla sem apagar nada e faz backup);
   - se o `settings.json` atual já tiver `model`, `effortLevel` ou hooks de outras ferramentas (proxies de modelo,
     compressores de saída etc.), avise; o merge não remove nada, mas o `effortLevel` do Opus passa a `medium`.
   Pergunte se pode instalar e se quer `--settings` e `--explore`.

7. **Instalação**: com o OK do usuário, rode `./install.sh` com as opções escolhidas.

8. **Verificação**:
   - `claude plugin details copilot-delegate@claude-copilot-delegate` lista 3 skills e 1 agente.
   - `ls ~/.copilot/agents/` tem `cop-worker`, `cop-reviewer` e `cop-tester`.
   - Peça ao usuário para rodar, num projeto dele: `cop "liste os 5 maiores arquivos e diga o que cada um faz"`.
     Deve voltar um resumo e a linha `[cop] job=... status=0`. Se der "Model ... is not available", o login ou o
     ID do modelo está errado (volte aos passos 2 e 4).
   - Explique que o Claude só carrega as mudanças numa sessão nova (ou com `/reload-plugins`).

9. **Resumo final** ao usuário: o que foi instalado, onde ficaram os backups (`*.bak-<data>`), e os comandos úteis:
   `/delegar <tarefa>`, `/revisar [foco]`, `cop --stats`, `./uninstall.sh` para remover.
