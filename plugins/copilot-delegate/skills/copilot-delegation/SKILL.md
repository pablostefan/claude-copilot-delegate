---
name: copilot-delegation
description: Delega trabalho mecânico ao GitHub Copilot CLI com o comando `cop` para economizar tokens. Use antes de escrever boilerplate, testes para código existente, refactors repetitivos, docs, ou de ler/varrer muitos arquivos e logs grandes; e para uma segunda revisão barata de um diff.
when_to_use: criar testes, scaffolding, CRUD, modelos/DTOs, serialização, renomear em vários arquivos, migrar API, gerar docs/README/changelog, "onde X é usado", resumir log ou arquivo grande, revisar diff antes de commit
allowed-tools: Bash(cop *) Bash(git diff *) Bash(git status *)
---

# Delegação ao Copilot CLI

Você é o orquestrador: planeja, escreve a spec, revisa e decide. O Copilot (`gpt-6-luna`) faz o braçal
e devolve um resumo curto. Isso só economiza se você **não** ler o que ele leu.

## Decida
| Delegue com `cop` | Faça você |
|---|---|
| Boilerplate, telas simples, modelos, JSON, CRUD | Arquitetura e decisões de design |
| Testes para código que já existe (`-R tester`) | Bugs sutis, concorrência, performance |
| Refactor mecânico em vários arquivos | Segurança, auth, pagamentos, migrações de dados |
| Docs, comentários, changelog | Mudança pequena (< ~20 linhas) num arquivo que você já leu |
| Varredura: "onde X é usado", resumir log grande | Algo que falhou 2x no `cop` |

## Comandos
Sempre passe `timeout: 600000` na chamada Bash do `cop` (o padrão do Bash é 2 min; o cop para sozinho em 9 min).

| Situação | Comando |
|---|---|
| Pergunta/varredura (não edita) | `cop "pergunta objetiva"` |
| Implementação no diretório atual | `cop -w "<spec>"` |
| Implementação isolada (recomendado se você também edita, ou em paralelo) | `cop -W "<spec>"` |
| Só testes (não pode tocar em código de produção) | `cop -R tester "<spec>"` |
| Segunda revisão do diff atual | `cop -R reviewer "foco: <o que importa>"` |
| Rodada de correção na mesma sessão | `cop -r <job> "falhou: <linhas do erro>. Corrija."` |
| Mais raciocínio / outro modelo / outro dir | `-e medium` · `-m <id>` · `-C <dir>` |

Cada chamada termina com `[cop] job=<id> status=<n> ...`. Guarde o `job` para `-r`, `--apply` e `--discard`.

## Spec (modelo para `-w`, `-W` e `-R tester`)
```
Objetivo: <uma frase>
Arquivos: <caminhos que podem ser alterados ou criados>
Siga o padrão de: <arquivo existente de exemplo>
Regras: <restrições: não mudar API pública, usar bloc, etc.>
Aceite: <o que precisa ser verdade no fim>
Verificação: <comando exato, ex.: fvm flutter test test/foo_test.dart>
```
Spec boa = arquivos explícitos + exemplo de padrão + comando de verificação. Sem isso o modelo barato erra.

## Fluxo com worktree (`-W`)
1. `cop -W "<spec>"` cria um git worktree a partir do HEAD e roda lá. Mudanças não commitadas do repo não vão junto.
2. O resultado mostra o diffstat do worktree. Revise com `git -C <worktree> diff HEAD -- <arquivo>`.
3. Correção: `cop -r <job> "..."` (continua no mesmo worktree e na mesma sessão).
4. Ficou bom: `cop --apply <job>` (aplica no repo e remove o worktree). Ruim: `cop --discard <job>`.
5. Vários `cop -W` podem rodar em paralelo sem conflito; aplique um por vez.

## Revisão (barata)
1. Leia o resumo e a linha `[cop]`. Status ≠ 0: veja o motivo antes de qualquer coisa.
2. `git diff --stat`, depois `git diff -- <arquivo>` só dos arquivos que importam.
3. Rode a verificação você mesmo. Confie no teste, não no resumo.
4. Mudança grande ou arriscada: `cop -R reviewer` antes de você ler o diff; leia com atenção os achados [alta].
5. Ajuste pequeno: faça você. Retrabalho: `cop -r <job>` com só as linhas relevantes do erro.
6. Não abra o log completo (`cop --last`) a menos que o resumo seja insuficiente.

## Limites do `cop`
Escrita libera edição e build/teste (flutter, dart, npm, python...). `tester` só escreve em arquivos de teste.
`reviewer` é sempre só leitura. Bloqueados sempre: git push/commit/reset/checkout/rebase/merge/branch/worktree,
rm, sudo, curl, `.env`, e chamar cop/copilot/claude. Commits ficam com você.
Comando extra: `COP_EXTRA_ALLOW="shell(make:*)" cop -w ...`.
