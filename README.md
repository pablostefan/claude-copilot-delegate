# claude-copilot-delegate

[![tests](https://github.com/pablostefan/claude-copilot-delegate/actions/workflows/test.yml/badge.svg)](https://github.com/pablostefan/claude-copilot-delegate/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Plugin do **Claude Code** que transforma o Claude em orquestrador e delega o trabalho mecânico ao
**GitHub Copilot CLI**, que roda modelos mais baratos. O Claude planeja, escreve a spec, revisa o diff e roda
a verificação. O Copilot lê os arquivos, escreve o código e itera nos testes. Só um resumo curto volta para o
contexto do Claude, que é onde os tokens são gastos.

```
Claude Code (orquestra)  ──cop -w "<spec>"──►  Copilot CLI (executa)  ──resumo ≤15 linhas──►  Claude revisa
```

## Recursos

- **`cop`**: wrapper seguro do `copilot -p`, que entra no PATH do Bash do Claude enquanto o plugin está ativo.
  - Modo leitura por padrão; `-w` libera edição e build/teste; nunca usa `--allow-all-tools`.
  - `-W` roda a tarefa num **git worktree isolado** (`cop --apply` / `cop --discard`).
  - `-r <job>` **continua a sessão** do Copilot na rodada de correção, sem reexplicar a tarefa.
  - `-R reviewer` (revisão só leitura do diff) e `-R tester` (só escreve arquivos de teste).
  - Timeout, corte de saída, log completo em arquivo, `cop --stats`, trava contra recursão.
- **Skills**: `copilot-delegation` (o Claude decide sozinho quando delegar), `/delegar <tarefa>` e `/revisar [foco]`.
- **Subagente** `copilot-worker` (Haiku) para tarefas com várias rodadas de teste e correção.
- **Configurações de economia** para o `settings.json` (effort, auto-compact, subagentes em Haiku, bloqueio
  de leitura de código gerado...), mescladas sem apagar nada.
- Custo fixo do plugin: cerca de **440 tokens por sessão** (medido com `claude plugin details`).

## Requisitos

- macOS ou Linux (no Windows, dentro do WSL), `bash`, `git`, `python3`
- [Claude Code](https://code.claude.com) 2.1.2xx ou mais novo
- [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/copilot-cli) autenticado (`copilot login`)

## Instalação

```bash
git clone https://github.com/pablostefan/claude-copilot-delegate ~/GitHub/claude-copilot-delegate
cd ~/GitHub/claude-copilot-delegate
bash tests/test_cop.sh                 # 45 testes com um copilot falso, não gasta nada
./install.sh --dry-run --settings      # mostra o que vai mudar
./install.sh --settings --explore      # instala, com backup de tudo
cop "liste os 5 maiores arquivos do projeto e diga o que cada um faz"   # teste real
```

Prefere que o Claude instale? Abra o Claude Code na pasta clonada e peça:
*"Siga o INSTALAR-COM-CLAUDE.md desta pasta e me peça confirmação antes de instalar."*

Só o plugin, sem clonar (sem os agentes do Copilot nem as configurações):

```bash
claude plugin marketplace add pablostefan/claude-copilot-delegate
claude plugin install copilot-delegate@claude-copilot-delegate
```

## Uso

No dia a dia você só conversa com o Claude: a skill faz ele delegar o que for mecânico. Para forçar:

```text
/delegar crie testes de unidade para lib/login/login_cubit.dart
/revisar foco em tratamento de erro
```

Manual, se quiser:

```bash
cop "onde o AuthRepository é usado?"           # leitura
cop -W "<spec>"                                # escrita isolada em worktree
cop -r last "falhou: <erro>. Corrija."         # continua a sessão
cop --apply <job>                              # traz as mudanças do worktree
```

O modelo padrão é `gpt-6-luna`. Troque com `COP_MODEL=<id>` ou `cop -m <id>` (veja os IDs em `copilot` → `/model`).

## Documentação

- [docs/GUIA.md](docs/GUIA.md): arquitetura, segurança, todas as opções, configurações de economia, riscos e referências.
- [INSTALAR-COM-CLAUDE.md](INSTALAR-COM-CLAUDE.md): roteiro para o Claude Code instalar numa máquina nova.

## Segurança

A allow-list do `cop` limita o que o Copilot pode fazer, mas **não é um sandbox**: comandos liberados no modo
escrita, como `npx`, `node` e `python3`, executam código arbitrário. Use em repositórios versionados, de
preferência com `-W`. O Copilot nunca faz commit, push nem apaga arquivos pelo `cop`; isso fica com você.

## Licença

[MIT](LICENSE)
