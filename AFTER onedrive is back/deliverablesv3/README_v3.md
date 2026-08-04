# deliverablesv3 — Pacote unificado para `xexr500/510` e `xexm200/210`

Pacote único de deploy que arruma os logs SSM/RHEL **para todos os quatro jobs**:

* **Série 5**: `xexr500` (Race-to-Ext MINI/WIP) e `xexr510` (Ultramate Build MINI)
* **Série 2**: `xexm200` (Race-to-Ext FULL) e `xexm210` (Ultramate Build FULL)

Os quatro jobs compartilham o mesmo framework EXT (chamam `xex010.ksh`,
`xex015.ksh`, `xex900.ksh`, `email_rpt.ksh`, `rpt_log_retention.ksh`),
então os patches dos arquivos compartilhados beneficiam todos de uma vez.

## Mapeamento job → script principal

| Job | Wrapper | Script principal | Tipo |
|---|---|---|---|
| `xexr500` | `xexr500.ksh` | `xex010.ksh` | MINI |
| `xexr510` | `xexr510.ksh` | `xex015.ksh` | MINI |
| `xexm200` | (wrapper externo) | `xex010.ksh` | FULL |
| `xexm210` | (wrapper externo) | `xex015.ksh` | FULL |

## Conteúdo do pacote (13 arquivos)

### Scripts patchados (5 arquivos com mudanças)

| Arquivo | Mudanças (`# rj132422 - ...`) |
|---|---|
| `xex010.ksh` | (a) `LOG` em path absoluto `/tmp/${JOBNAME}_$(basename $0 .ksh_run)_$$.sqlout` em vez de relativo; (b) `: > $LOG` pra pre-truncar; (c) cat-back após cada heredoc `CODE_BLOCK` do `sp_race_to_ext` (Step020R) e `sp_update_special_graphics` (Step030R) **com filtro `grep -v 'Post checkin date set, no need to run post checkin process'`** pra não inflar o job log com a noise do `dbms_output` (cai de 1.27MB pra ~10KB no `xexm200`); (d) re-export defensivo de `$LOG` depois de `email_rpt.ksh`; (e) cleanup `rm -f "$LOG"` no Step999R |
| `xex015.ksh` | (a) `LOG` em path absoluto; (b) `set +xv` explícito no Step010R em vez de `set -` (que era ambíguo entre ksh88/ksh93); (c) cat-back após `xex900.ksh`, após cada heredoc `%` de `PKG_ULTRAMATE_BUILD` e `PKG_ULTRAMATE_PREPARSE`; (d) re-export defensivo de `$LOG` depois de `email_rpt.ksh`; (e) cleanup no Step030R/Step999R |
| `xex900.ksh` | **Sem mudança** — já redireciona corretamente para `$LOG` que o caller fornece, e o caller faz o cat-back |
| `email_rpt.ksh` | (a) Removido `export LOG=/dev/null` (era o "Treatment for RHEL" que silenciava o sqlplus interno); (b) trocado por `LOG=/tmp/email_rpt_$$.sqlout` + `: > $LOG`; (c) adicionado cat-back `[ -s "$LOG" ] && cat "$LOG"` + `rm -f "$LOG"` após o `CODE_BLOCK`. Resultado: o `*** WARNING *** Report ID: <id> is not defined in email_xref table` volta a aparecer no job log |
| `rpt_log_retention.ksh` | (a) Adicionado `LOG=/tmp/rpt_log_retention_$$.sqlout` + `: > $LOG` antes do `sqlplus` (não herda mais `$LOG` envenenado do parent); (b) cat-back + `rm -f "$LOG"` após o `CODE_BLOCK`. Resultado: banner Oracle + `PL/SQL completed` + `Disconnected from` voltam a aparecer. **Self-contained** — funciona pra qualquer caller |

### Scripts/configs sem mudança (8 arquivos, incluídos pra deploy completo)

`xex017.ksh`, `xex018.ksh`, `xex019.ksh`, `xex999.ksh`, `xexr500.ksh`,
`xexr510.ksh`, `race_ext.ksh`, `zxex000.prm`.

Esses ficam intactos mas vão no pacote pra você fazer `cp -r deliverablesv3/* /destino/`
sem precisar misturar de versões diferentes.

## Onde fica cada arquivo no servidor (sugerido)

| Local típico | Arquivos |
|---|---|
| `/mdev/race/ext/bin/` (ou `/stage/race/ext/bin/`) | `xexr500.ksh`, `xexr510.ksh`, `xex010.ksh`, `xex015.ksh`, `xex017.ksh`, `xex018.ksh`, `xex019.ksh`, `xex900.ksh`, `xex999.ksh`, `race_ext.ksh` |
| `/mdev/race/ext/prm/` (ou `/stage/race/ext/prm/`) | `zxex000.prm` |
| `/mdev/race/share/bin/` (ou `/stage/race/share/bin/`) | `email_rpt.ksh`, `rpt_log_retention.ksh` |

Conferir os caminhos reais no ambiente com `which email_rpt.ksh` e
`which rpt_log_retention.ksh` antes de copiar.

## Como identificar as mudanças

Todos os comentários novos têm prefixo `# rj132422 - ...`.
Pra ver o diff só do que mudou em cada arquivo:

```bash
grep -n 'rj132422' deliverablesv3/xex010.ksh
grep -n 'rj132422' deliverablesv3/xex015.ksh
grep -n 'rj132422' deliverablesv3/email_rpt.ksh
grep -n 'rj132422' deliverablesv3/rpt_log_retention.ksh
```

## Validação pós-deploy

### Série 5 (`xexr500`/`xexr510`)

| Verificação | Esperado |
|---|---|
| `grep -c 'SQL\*Plus: Release' xexr500_*.log` | 1 ou 2 (depende de RUN_TYPE) |
| `grep -c 'SQL\*Plus: Release' xexr510_*.log` | 5 (xex900 + email_rpt + 2x rpt_log_retention + PKG_ULTRAMATE) |
| `grep '\*\*\* WARNING' xexr510_*.log` | Aparece o WARNING do `email_xref` |
| `ls /tmp/*_xex0*.sqlout /tmp/email_rpt_*.sqlout /tmp/rpt_log_retention_*.sqlout` | Vazio depois do job (cleanup correto) |

### Série 2 (`xexm200`/`xexm210`)

| Verificação | Esperado |
|---|---|
| Tamanho do `xexm200_*.log` | Algumas centenas de linhas (~10-30KB), não 1.27MB |
| `grep -c 'Post checkin date set' xexm200_*.log` | **0** (filtro funcionando) |
| `grep -c 'SQL\*Plus: Release' xexm200_*.log` | 6 |
| `grep -c 'SQL\*Plus: Release' xexm210_*.log` | 6 |
| `grep '\*\*\* WARNING' xexm200_*.log` e `xexm210_*.log` | Aparece o WARNING do `email_xref` em ambos |

## Limitações / O que NÃO está coberto

* Outras mensagens de `dbms_output` repetitivas em procedures que não
  sejam `sp_race_to_ext`/`sp_update_special_graphics` continuam passando
  pelo cat-back sem filtragem. Se aparecer noise nova, empilhar mais
  `grep -v 'padrão'` no cat-back correspondente.
* `xex017.ksh`/`xex018.ksh`/`xex019.ksh` (background workers do FULL build)
  não foram patchados — eles gravam direto em `${FULL_LOG1}`/`${FULL_LOG2}`
  e o framework já faz `grep -c 'ORA-'` neles pra detecção de erro, então
  o ciclo deles é diferente e não tem o mesmo problema.

## Rollback

Voltar os arquivos da versão anterior (em `RCS`, ou `~/backup/` se você
fez backup local). Como nenhuma mudança quebra a interface dos scripts
(receber/devolver os mesmos parâmetros), rollback é seguro a qualquer
momento.
