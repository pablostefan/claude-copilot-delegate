# Guia: Claude orquestrador + Copilot CLI executor

Objetivo: gastar menos tokens do Claude Code sem perder qualidade. O Claude (Opus) planeja, escreve a spec,
revisa o diff e roda a verificação. O GitHub Copilot CLI (`gpt-6-luna`) faz o braçal: lê muitos arquivos,
gera código, roda testes e corrige até passar. Só um resumo de até 15 linhas volta para o Claude.

Baseado na documentação oficial do Claude Code (costs, plugins, skills, sub-agents, model-config, settings,
env-vars, hooks) e do Copilot CLI (programmatic reference, command reference, custom agents, custom
instructions), lida em 06/11/2026. Testado com Claude Code 2.1.310+ e Copilot CLI 1.0.103 (macOS, bash 3.2, e Linux).

---

## 1. Arquitetura

```
Você
 │
 ▼
Claude Code (Opus, effort medium)          ← planeja, decide, revisa, roda a verificação
 │  skill copilot-delegation (carrega só quando relevante)
 │  Bash: cop -w "<spec>"                   ← ~300 tokens de ida, ≤15 linhas de volta
 ▼
cop (bin do plugin)                         ← permissões restritas, timeout, log, corte de saída
 │  copilot -p ... --agent cop-worker --model gpt-6-luna
 ▼
Copilot CLI (gpt-6-luna)                    ← lê, edita, roda flutter test, itera
```

Por que economiza: o custo do Claude é dominado por **contexto** (cada mensagem reenvia o histórico,
incluindo cada arquivo lido e cada saída de comando). Quem lê os 20 arquivos e as 5 rodadas de teste
é o Copilot; o contexto do Claude recebe só a spec e o resumo.

### Por que plugin

A doc do Claude Code recomenda empacotar skills, agentes e executáveis num plugin. Vantagens concretas:
- `bin/` do plugin entra no `PATH` do Bash do Claude: o `cop` funciona sem instalar nada em `~/.local/bin`.
- Skills carregam sob demanda: as regras de delegação custam ~220 tokens fixos (só a descrição) e ~1,6k só
  quando usadas. No CLAUDE.md custariam sempre. (`claude plugin details` mede: **~437 tokens fixos no total**.)
- Versionado, validável (`claude plugin validate`), liga/desliga por projeto (`claude plugin disable`).

## 2. Estrutura do repositório

```
claude-copilot-delegate/
├── .claude-plugin/marketplace.json      marketplace "claude-copilot-delegate"
├── plugins/copilot-delegate/
│   ├── .claude-plugin/plugin.json
│   ├── bin/cop                          wrapper do Copilot CLI
│   ├── skills/copilot-delegation/       regras + modelo de spec (o Claude carrega sozinho)
│   ├── skills/delegar/                  comando /delegar <tarefa>
│   ├── skills/revisar/                  comando /revisar [foco]
│   ├── agents/copilot-worker.md         subagente Haiku para tarefas com várias rodadas
│   └── README.md
├── copilot/agents/                     agentes do lado do Copilot: cop-worker, cop-reviewer, cop-tester
├── settings/
│   ├── settings-economia.json           ajustes de economia para o settings.json
│   ├── merge_settings.py                mescla sem apagar nada, com backup e --dry-run
│   ├── CLAUDE-snippet.md                2 linhas para o CLAUDE.md global
│   └── agents/Explore.md                Explore em Haiku (opcional)
├── tests/test_cop.sh                    45 testes com um copilot falso (inclui worktree e sessão)
├── install.sh / uninstall.sh
└── docs/GUIA.md
```

## 3. Instalação

```bash
# clone num lugar fixo (o marketplace local aponta para esta pasta)
git clone https://github.com/pablostefan/claude-copilot-delegate ~/GitHub/claude-copilot-delegate
cd ~/GitHub/claude-copilot-delegate
bash tests/test_cop.sh                 # 45 ok, não chama o Copilot de verdade
./install.sh --dry-run --settings      # mostra tudo o que mudaria
./install.sh --settings --explore      # instala (com backup de tudo)
```

O `install.sh` faz: `claude plugin validate`, `claude plugin marketplace add`, `claude plugin install
copilot-delegate@claude-copilot-delegate`, copia os agentes para `~/.copilot/agents/`, anexa 2 linhas ao CLAUDE.md global
e, com `--settings`, mescla o JSON de economia (listas são unidas, nada é removido).

Só o plugin, direto do GitHub (sem os agentes do Copilot nem as configurações; o papel `worker` funciona com
um contrato embutido, `reviewer` e `tester` precisam dos agentes do `install.sh`):

```bash
claude plugin marketplace add pablostefan/claude-copilot-delegate
claude plugin install copilot-delegate@claude-copilot-delegate
```

Teste real, no seu terminal (precisa do `copilot login` feito):

```bash
cd ~/GitHub/algum-projeto
cop "liste os 5 maiores arquivos .dart e diga em 1 linha o que cada um faz"
cop --stats
```

No Claude: abra uma sessão nova (ou `/reload-plugins`) e peça uma tarefa mecânica, ou force com
`/delegar crie testes de unidade para lib/foo/foo_cubit.dart`.

## 4. O comando `cop`

```bash
cop "onde o AuthRepository é usado?"       # leitura: não edita nada
cop -w "<spec>"                            # escrita: edita e roda build/teste
cop -e medium -w "<spec>"                  # mais raciocínio
cop -m auto "<pergunta>"                   # Copilot escolhe o modelo
cop -C ~/GitHub/outro "<pergunta>"         # outro diretório
cop -W "<spec>"                            # escrita isolada num git worktree
cop -R tester "<spec>"                     # só escreve arquivos de teste
cop -R reviewer "foco: tratamento de erro" # revisão do diff, só leitura
cop -r last "falhou: <erro>. Corrija."     # continua a sessão do último job
cop --jobs | --apply JOB | --discard JOB   # gerencia jobs e worktrees
cop -t 300 -w "<spec>"                     # timeout menor (padrão 540s)
cop --stats | cop --last                   # histórico e último log
```

| Variável | Padrão | Para quê |
|---|---|---|
| `COP_MODEL` | `gpt-6-luna` | modelo padrão |
| `COP_EFFORT` | `low` | reasoning effort (`""` usa o padrão do modelo) |
| `COP_MAX_CHARS` | `4000` | máximo de caracteres devolvidos ao Claude |
| `COP_TIMEOUT` | `540` | segundos (o Bash do Claude corta em 600) |
| `COP_EXTRA_ALLOW` | — | permissões extras, ex.: `"shell(./gradlew:*) shell(pod:*)"` |
| `COP_GITHUB_MCP` | `0` | `1` liga o MCP do GitHub dentro do Copilot |

Códigos de saída: `0` ok, `2` uso errado, `3` recursão bloqueada, `4` job/worktree inválido, `124` timeout, outros vêm do Copilot.

### Worktree isolado (`-W`)

Inspirado no [cop-pilot](https://pypi.org/project/cop-pilot/). Resolve o risco de o Copilot e o Claude (ou dois
`cop` em paralelo) editarem os mesmos arquivos.

```bash
cop -W "<spec>"            # cria ../.cop-worktrees/<repo>-<job> na branch cop/<job>, a partir do HEAD
cop -r <job> "corrija X"   # rodada de correção no mesmo worktree
cop --apply <job>          # aplica as mudanças no repo (git apply --3way), remove worktree e branch
cop --discard <job>        # joga fora
```

- O worktree parte do último commit: mudanças não commitadas do repo não vão junto (o `cop` avisa).
- O Copilot é avisado para rodar `pub get`/`npm install` no worktree antes dos testes.
- Em conflito, o `--apply` mantém o worktree e salva o patch em `$TMPDIR/cop-logs/<job>.patch`.
- `COP_WORKTREE_DIR` muda onde os worktrees ficam.

### Continuar a sessão (`-r`)

Inspirado no [claude-delegator](https://github.com/jarrodwatts/claude-delegator). Cada job grava o UUID da sessão
do Copilot (`--session-id`). `cop -r <job>` usa `--resume`: a rodada de correção não precisa reexplicar a tarefa
nem reler os arquivos, e herda diretório, modo, papel e modelo do job. `-r last` pega o mais recente.

### Papéis (`-R`)

Inspirado no `clink` do [PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server) e no crítico do
[conductor](https://github.com/akaCT/conductor). Cada papel é um agente do Copilot com contrato de saída próprio.

| Papel | Permissões | Saída |
|---|---|---|
| `worker` (padrão) | as do modo (`-w`/`-W` ou leitura) | RESULTADO / FEITO / ARQUIVOS / VERIFICAÇÃO |
| `reviewer` | sempre só leitura | VEREDITO + achados `[alta/média/baixa] arquivo:linha` |
| `tester` | escreve só em `test/`, `*_test.*`, `*.spec.*`...; roda testes | TESTES / VERIFICAÇÃO / BUGS SUSPEITOS |

Uso típico: `cop -R reviewer` antes de o Claude ler um diff grande; o Claude só confere os achados `[alta]`.
Usar outro modelo na revisão (`-m <id do Haiku>`) dá uma segunda opinião de fato diferente.

### Segurança (o que o `cop` libera e bloqueia)

O `cop` **nunca** usa `--allow-all-tools`/`--yolo`. Em modo `-p` o Copilot nega qualquer ferramenta que não
tenha regra de allow, então a lista abaixo é o limite real:

- Leitura (sempre): `read`, `ls cat head tail wc find grep rg tree file`, `git status/diff/log/show/blame/ls-files`.
- Escrita (`-w`): `write`, `flutter fvm dart melos very_good`, `npm npx pnpm yarn bun node`, `python3 pytest uv make`,
  `mkdir mv cp touch`, `git add/mv`.
- Bloqueado sempre (deny vence allow): `git push/commit/reset/checkout/restore/rebase/stash/clean/merge/branch/switch/worktree`, `rm`, `sudo`,
  `chmod`, `curl`, `wget`, escrita em `.env*`, `*.jks`, `*.keystore`, e chamar `cop`, `copilot` ou `claude`.
- `--disable-builtin-mcps`: o MCP do GitHub fica desligado (menos contexto e menos risco).
- Commits ficam com você/Claude, depois da revisão.

**Recursão**: o Copilot lê `CLAUDE.md` e `AGENTS.md` do repositório. Se o CLAUDE.md disser "delegue ao cop",
o Copilot poderia chamar o `cop` de novo. Por isso há duas travas: `COP_ACTIVE=1` (o `cop` sai com código 3)
e o deny de `shell(cop:*)`.

## 5. Como o Claude decide e delega

A skill `copilot-delegation` define a regra. Resumo:

| Delegue com `cop` | Faça no Claude |
|---|---|
| Boilerplate, telas simples, modelos, JSON, CRUD | Arquitetura e design |
| Testes para código existente | Bugs sutis, concorrência, performance |
| Refactor mecânico em vários arquivos | Segurança, auth, pagamentos, migrações |
| Docs, comentários, changelog | Mudança pequena num arquivo já lido |
| "Onde X é usado", resumir log grande | O que falhou 2x no `cop` |

**Spec** (é o que define a qualidade do resultado do modelo barato):

```
Objetivo: criar testes de unidade para o LoginCubit
Arquivos: test/login/login_cubit_test.dart (criar)
Siga o padrão de: test/profile/profile_cubit_test.dart
Regras: bloc_test + mocktail; não alterar lib/
Aceite: cobre sucesso, erro de rede e credencial inválida
Verificação: fvm flutter test test/login/login_cubit_test.dart
```

**Revisão barata**: `git diff --stat`, depois `git diff -- <arquivo>` só do que importa, e rodar a
verificação. Não reler o projeto.

**`/delegar`, `/revisar`, `copilot-worker` e `cop` direto**
- `cop` direto: o padrão. Uma chamada Bash.
- `/delegar <tarefa>`: quando você quer forçar a delegação.
- `/revisar [foco]`: segunda revisão do diff pelo Copilot; o Claude confere só os achados citados.
- `copilot-worker` (subagente Haiku, `maxTurns: 12`): tarefas que precisam de várias rodadas de
  "roda teste → corrige". As rodadas ficam no contexto do Haiku, não do Opus.

## 6. Configurações de economia no Claude Code

Tudo em `settings/settings-economia.json`. Cada item foi conferido na doc (e os nomes de variáveis no
binário do Claude Code 2.1.318). Revise antes de aplicar: valem para todos os projetos.

| Ajuste | Efeito |
|---|---|
| `modelSettings.claude-opus-5-5.effortLevel: "medium"` | **O maior ganho.** O padrão do Opus 5.5 já é `medium`; muita gente deixa forçado em `high`. Suba com `/effort high` só quando precisar. |
| `autoCompactWindow: 200000` | O Opus 5.5 roda com 1M de contexto por padrão. Compactar em 200k evita mensagens cada vez mais caras. |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` | Compacta em 75% da janela, antes de encher. |
| `CLAUDE_CODE_SUBAGENT_MODEL=haiku` | Subagentes sem `model` próprio rodam em Haiku. |
| `BASH_MAX_OUTPUT_LENGTH=15000` | Corta saídas enormes de comando (padrão 30000). |
| `MAX_MCP_OUTPUT_TOKENS=10000` | Corta respostas enormes de MCP. |
| `CLAUDE_CODE_GLOB_NO_IGNORE=false` | O Glob passa a respeitar o `.gitignore` (por padrão ele lista arquivos ignorados também). |
| `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` | Desliga sugestões de prompt (chamadas extras). |
| `permissions.deny` com `Read(**/build/**)`, `.dart_tool`, `.fvm`, `Pods`, `node_modules`, `coverage`, `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.min.js` | O Claude não lê código gerado. `.claudeignore` **não funciona** (a doc diz para usar deny de `Read`). |
| `permissions.allow`: `Bash(cop *)`, `git diff`, `git status` | Delegação e revisão sem prompts de permissão. |

**Modelo**: `opus` funciona bem para orquestrar. Alternativa: `opusplan` (Opus no plan mode, Sonnet na
execução). Se você usa um proxy que escolhe o modelo por turno, use um ou outro, não os dois.

**Explore em Haiku** (`--explore`): o Explore embutido herda o modelo principal (Opus). Um agente de usuário
chamado `Explore` com `model: haiku` e `omitClaudeMd: true` o substitui (a doc descreve isso).

## 7. Mais pontos para economizar

**Hábitos (maior impacto, custo zero)**
- `/clear` ao mudar de tarefa. Antes, `/rename` para poder voltar com `/resume`.
- `/compact Foco em X` quando a conversa for longa mas ainda for a mesma tarefa.
- `/context` mostra o que ocupa o contexto. `/usage` mostra o consumo.
- Plan mode (Shift+Tab) em tarefas grandes. `Esc` ou `/rewind` assim que o rumo estiver errado.
- Prompts específicos com arquivo e critério de aceite ("corrija X em lib/a.dart, rode o teste Y") em vez de
  "melhore o login".

**Contexto fixo (pago em toda mensagem)**
- Veja o custo fixo de cada plugin: `claude plugin details <plugin>@<marketplace>`. Desative por projeto o que
  não usa ali (`claude plugin disable <plugin> --scope project`).
- Plugins **sincronizados do claude.ai** e **conectores do claude.ai** (Gmail, Calendar, Drive...) também
  entram no Claude Code. Em projeto de código raramente servem. Para desligar os conectores:
  `"ENABLE_CLAUDEAI_MCP_SERVERS": "false"` no `env` (no `.claude/settings.json` do projeto, se for só nele).
- Rode `claude mcp list`: MCPs que falham ou pedem login ainda ocupam espaço. Corrija ou desligue em `/mcp`.
- Prefira CLI a MCP quando existir (`gh` em vez do MCP do GitHub). A doc recomenda isso.
- CLAUDE.md abaixo de 200 linhas; fluxos detalhados viram skills (carregam sob demanda).
- Adicione ao CLAUDE.md uma seção `# Compact instructions` dizendo o que preservar ao compactar
  (ex.: "preserve decisões, caminhos de arquivos e comandos de verificação; descarte saídas de teste").

**Saída de ferramentas**
- Hooks `PreToolUse` que filtram/comprimem a saída do Bash (a doc de custos mostra um exemplo) somam-se ao `cop`.
- Para testes, rode só o arquivo relevante (`flutter test test/x_test.dart`), não a suíte inteira.

**Lado do Copilot (não custa tokens do Claude, mas afeta qualidade/velocidade do Luna)**
- Arquivos em `~/.copilot/instructions/*.instructions.md` entram em toda chamada. Use `applyTo`
  (ex.: `applyTo: "**/*.dart"`) para carregar só quando fizer sentido. `copilot instruction list` mostra o que carrega.
- Plugins/agentes do Copilot com YAML inválido aparecem como aviso em `~/.copilot/logs/`; corrija ou remova.
- Se quiser um teto por chamada: adicione `--max-ai-credits N` no `cop` (flag existe no 1.0.103).

## 8. Manutenção

- Editou o plugin? `git pull`, depois `claude plugin marketplace update claude-copilot-delegate && claude plugin update copilot-delegate@claude-copilot-delegate`.
- Rodar os testes depois de mexer no `cop`: `bash tests/test_cop.sh`.
- Desinstalar: `./uninstall.sh` (CLAUDE.md, settings.json e Explore.md têm backups `.bak-<data>`).
- Copilot atualizou e algo quebrou? `copilot --help` e confira as flags usadas no `cop`
  (`-s`, `--stream`, `--no-ask-user`, `--allow-tool=`, `--deny-tool=`, `--agent`, `--usage-output-file`,
  `--disable-builtin-mcps`, `--max-autopilot-continues`).

## 9. Riscos e como o kit lida com eles

| Risco | Mitigação |
|---|---|
| Economia não acontecer (Claude relê tudo para revisar) | Skill manda revisar por `--stat` e trechos; meça com `/usage` e `cop --stats` |
| Código plausível mas errado | Verificação obrigatória rodada pelo Claude; `-R reviewer` como segunda opinião |
| Resumo do Copilot "mentir" | O Claude roda o teste ele mesmo |
| Allow-list não é sandbox (`npx`, `node`, `python3` executam qualquer coisa) | Trabalhe numa branch; prefira `-W`; nada é commitado pelo Copilot |
| Conflito de edição | `-W` isola cada tarefa num worktree |
| Lentidão | Tarefas independentes em paralelo com `-W`; timeout de 9 min |
| Copilot mudar flags/auth expirar | `bash tests/test_cop.sh` + seção Manutenção |

## 10. Projetos parecidos (referências)

- [developer-kit copilot-cli skill](https://skillselion.com/skills/giuseppe-trisciuoglio/developer-kit/copilot-cli): skill que chama `copilot -p`; usa `--allow-all-tools`.
- [cop-pilot](https://pypi.org/project/cop-pilot/): jobs assíncronos do Copilot em worktrees (alpha, depende do Herdr). Também usa o nome `cop`: não instale os dois.
- [PAL MCP / clink](https://github.com/BeehiveInnovations/pal-mcp-server): ponte MCP para Gemini/Codex/Qwen com papéis.
- [claude-delegator](https://github.com/jarrodwatts/claude-delegator): especialistas Codex/Gemini via MCP, com sessão contínua.
- [conductor](https://github.com/akaCT/conductor): subagentes por nível de modelo + painel crítico.
- [claude-code-router](https://github.com/musistudio/claude-code-router): troca o modelo por trás do Claude (abordagem de proxy).

## 11. O que não foi confirmado

- O ID exato do Haiku no Copilot: veja em `copilot` → `/model`.
- Se o `--resume` em modo `-p` mantém o agente (papel) da sessão original. A combinação de flags do `cop`
  é aceita pelo `copilot` 1.0.103.
- Quanto cada modelo do Copilot consome do plano: a doc de multiplicadores não lista o `gpt-6-luna`.
  O `cop` grava o consumo de cada chamada em `$TMPDIR/cop-logs/*.usage.json`.
