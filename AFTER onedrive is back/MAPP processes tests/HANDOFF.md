# HANDOFF — Migração MAPP/ALTP: remoção prod3nt + AIX→RHEL

> Documento de passagem de contexto. Cole isto (ou aponte para ele) ao abrir
> um novo chat para continuar o trabalho sem perder o histórico.

---

## 1. A tarefa

- **Story:** AES-XXXX (número ainda NÃO atribuído — placeholder em todos os arquivos)
- **Predecessora:** AES-3175 (mesma coisa para o fluxo OEM — concluída)
- **Análise relacionada:** AES-3180 (Rafael Deitos mapeou o processo MAPP/prod3nt)
- **Responsável:** Rodrigo Jasinski (usuário `rj132422`)
- **Objetivo:** remover a dependência do servidor **prod3nt** (que vai ser
  decommissioned, não migra pra AWS) dos scripts batch MAPP/ALTP, e ao mesmo
  tempo converter os scripts de **AIX para AWS RHEL**.

---

## 2. Decisões importantes (houve vários pivots — leia com atenção)

1. **Abordagem inicial (descartada):** trocar `fileget.exp`/`fileput.exp` por
   `scp` contra o FTP Mitchell, igual foi feito na AES-3175 (OEM).
2. **Pivot do Julian (abordagem ATUAL):** usar **NFS mount** — o NAS é montado
   localmente no servidor Linux e os scripts usam `cp`/`mv`/`sed`/`tr` locais
   em vez de FTP. Mais simples, mais rápido, mais perto do código original.
3. **Folder final NÃO decidido.** Para os testes AGORA usa-se um local
   TEMPORÁRIO: `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev` — uma
   subpasta dentro de um mount NFS que JÁ EXISTE (o do OEM_Repair_Doc).
   Não precisa de ticket para o temporário.
4. **Caminho é configurável:** criado o arquivo `altp_ftp_data.ksh`. Quando o
   folder definitivo for decidido = trocar UMA linha, nenhum script muda.
5. **Fora de escopo:** prod4nt e o `Combine_Stage.bat` do Chuck (lado Windows,
   task separada); referências a `${NOVELL}race` (não encaixam na árvore altp/).
6. **`fileget.exp`/`fileput.exp` NÃO foram tocados** — são procedures
   compartilhados por dezenas de outros scripts. A task só deixa de chamá-los.

---

## 3. Ambiente / servidores

| Item | Valor |
|---|---|
| Servidor DEV (RADD) | `dawapp7017l` (RADD.MITCHELL.COM) |
| Servidor PROD (RADP) | `pawapp7017l` |
| NFS server | `dawsvm7001a.staging.int` |
| `$RACE` base (dev) | `/mdev/race` — já montado via NFS |
| Mount NFS de referência (já funciona) | `dawsvm7001a.staging.int:/oemdocrepsharedev` → `/nas/mdev/OEM_Repair_Doc_Repository` |
| Local de teste TEMPORÁRIO | `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev` |
| Usuários com permissão | `race_b1`, `rj132422` |
| Diretório dos scripts | `altp/bin` (confirmar com `which xamref.ksh`) |

---

## 4. Abordagem técnica (padrões de conversão aplicados)

Arquivo de config novo `altp_ftp_data.ksh` define:
- `ALTP_FTP_DATA` = caminho base (hoje o temporário)
- `ALTP_DIR` = `$ALTP_FTP_DATA/altp`
- `ALTP_NAPA_DIR` = `$ALTP_FTP_DATA/altp/NAPA`
- `ALTP_INTRPT_DIR` = `$ALTP_FTP_DATA/altp/Internal_Rpts`
- `ALTP_CUSTRPT_DIR` = `$ALTP_FTP_DATA/altp/Customer_Rpts`

Todos os sub-scripts ALTP fazem `. altp_ftp_data.ksh` logo após o `trap`.

| Original (AIX + prod3nt) | Novo (RHEL + NFS) |
|---|---|
| `fileget.exp f u d` (binário) | `cp ${d}/${f} ${u}` + check `wc -c` |
| `fileget.exp f u d ascii` | `cp` + `tr -d '\r'` (CRLF→LF) |
| `fileput.exp f nome d ascii` | `sed 's/\r*$/\r/' f > ${d}/nome` (LF→CRLF) |
| `${NOVELL}altp` | `${ALTP_DIR}` (e variantes) |
| `grep 'Information ret' log` | `wc -c` direto nos arquivos locais |
| `[ var -eq var ]` (nomes sem `$`) | `[[ "$var" -eq "$var" ]]` |
| `echo "...\n..."` | `print "...\n..."` |
| `\| tee $LOG` | `> $LOG 2>&1` (preserva exit code) |

---

## 5. O que está PRONTO (pasta deliverables/)

### Scripts modificados/novos — todos validados (bash -n OK, ASCII, sem CRLF, sem prod3nt live)

| Arquivo | Status |
|---|---|
| `altp_ftp_data.ksh` | NOVO — config do caminho |
| `xamref.ksh` | Modificado — 1 GET + 3 PUT. Usado por XAMR100 e XAMR900 |
| `xamupd.ksh` | Modificado — 1 GET + 3 PUT. Usado por XAMR101/201/901 |
| `xamrpt.ksh` | Modificado — 1 GET. Usado por XAMR102/202/902 |
| `xam200.ksh` | Modificado — 2 GET + 4 PUT + 5 fixes AIX. Cadeia NAPA |
| `xam010.ksh` | Modificado — 3 PUT live + limpeza não-ASCII |
| `xam001.ksh` `xam030.ksh` `xam069.ksh` | Modificados — 1 GET cada + fixes AIX |
| `xamr200.ksh` | Modificado — 1 linha (`echo`→`print`). ÚNICO wrapper que precisou |

### Wrappers NÃO modificados (já eram RHEL-clean — confirmado por varredura)

`xamr100`, `xamr101`, `xamr102`, `xamr900`, `xamr901`, `xamr902`,
`xamr201`, `xamr202`, `xamr001`, `xamr010`, `xamr030`, `xamr069`
— continuam no servidor como estão, NÃO substituir.

### Documentos de apoio (deliverables/)

| Arquivo | Conteúdo |
|---|---|
| `README_deploy.md` | Passo a passo de deploy e execução |
| `e2e_test_plan_keystone.md` | Checklist detalhado do teste E2E |
| `altp_test_companion.html` | Painel visual (fluxograma SVG + mapa arquivo→pasta + checklist) |
| `altp_flow_diagrams.md` | Diagramas Mermaid (visão conceitual) |
| `as_is_to_be_dev.md` | Tabela as-is/to-be com os 3 estados do caminho |
| `CHANGELOG.md` | Registro completo das mudanças |
| `setup_test_env.sh` | Cria a árvore de pastas no local de teste |
| `sctask_nfs_mount_dev_v2.txt` | RASCUNHO do ticket NFS — NÃO submeter ainda |

---

## 6. Estado ATUAL — o que o usuário vai fazer agora

O usuário **não tem** os arquivos `keystone_*`. Tem os arquivos da cadeia
**Multi-supplier (XAMR900)**:
- `multiple_combined.txt` — input do XAMR900
- `multiple_refproc.txt` — round-trip (XAMR900 gera / XAMR901 lê)
- `multiple_rpt_prov.txt` — round-trip (XAMR901 gera / XAMR902 lê)

**Decisão:** testar a cadeia **XAMR900 → 901 → 902** em vez da Keystone. Usa
os MESMOS sub-scripts (`xamref`/`xamupd`/`xamrpt`) — só muda o qualifier
(`multiple` em vez de `keystone`) e os nomes dos arquivos. "keystone" e
"multiple" são apenas qualifiers vindos do parm `zxamvbls.prm`; os scripts
são genéricos.

**Vantagem:** o usuário tem os arquivos intermediários — pode usá-los como
GABARITO: rodar XAMR900, comparar o `multiple_refproc.txt` gerado com o que
já tem; se baterem, o `xamref` migrado está correto.

**Deploy para o teste XAMR900 — 4 arquivos para `altp/bin`:**
- `altp_ftp_data.ksh` (novo)
- `xamref.ksh` (substitui — backup RCS antes, original v1.4)
- `xamupd.ksh` (substitui — original v1.5)
- `xamrpt.ksh` (substitui — original v1.17)

Os wrappers `xamr900/901/902` já estão no servidor, NÃO tocar.

---

## 7. ITENS EM ABERTO / próximos passos

| # | Item | Situação |
|---|---|---|
| 1 | Número da story `AES-XXXX` | Não atribuído. Quando sair: find/replace global nos comentários `# Change rj132422 - 20260424 - AES-XXXX` |
| 2 | Atualizar docs de teste para a cadeia Multiple | OFERECIDO mas não feito. `e2e_test_plan_keystone.md`, `README_deploy.md`, `altp_test_companion.html` estão escritos para Keystone — usuário vai rodar Multiple (XAMR900) |
| 3 | Line endings para analistas | Os PUTs escrevem CRLF via `sed`. Validar no teste se o analista abre OK no Windows |
| 4 | Folder NAS definitivo | Não decidido. Quando decidir: trocar 1 linha em `altp_ftp_data.ksh`. SCTASK rascunhado mas NÃO submeter |
| 5 | Verificação RCS RADD vs RADP | Julian pediu confirmar que estrutura `/mdev/race`, `/prod/race`, scripts e histórico RCS batem entre os 2 servidores. NÃO feito ainda |
| 6 | `xam010.ksh` — 4 `fileput.exp` restantes | São DEAD CODE (dentro de blocos `: <<'END_COMMENT'`). Deixados de propósito, documentado no CHANGELOG |
| 7 | `${NOVELL}race` | Fora de escopo. Mas se prod3nt morrer, qualquer uso LIVE de `${NOVELL}race` no codebase quebra — rastrear separadamente |
| 8 | prod4nt / `Combine_Stage.bat` do Chuck | Task separada, lado Windows. Coordenar como o Chuck vai gravar no novo local |
| 9 | Mount NFS em PROD (RADP) | "NAS existe mas não montado ainda" (palavras do Julian). "Clone não está pronto". Esperar sinal do Julian |

### Sequência geral do projeto (onde estamos)

1. ✅ Entender fluxo, mapear scripts, documentar
2. ✅ Converter os scripts (prod3nt→NFS + AIX→RHEL)
3. ⬜ Verificar estrutura RADD/RADP + RCS (pedido do Julian)
4. ⬜ Deploy dos 4 arquivos no RADD
5. ⬜ `setup_test_env.sh` + colocar `multiple_combined.txt`
6. ⬜ Rodar teste E2E XAMR900→901→902 + comparar com gabarito
7. ⬜ Coletar evidências, anexar na story
8. ⬜ (depois) mount NFS em RADP + promover scripts + testar prod

---

## 8. Próxima ação sugerida para o novo chat

O usuário provavelmente vai querer um destes:
- **(a)** Atualizar os docs de teste (`e2e_test_plan`, `README_deploy`,
  `altp_test_companion.html`) da cadeia Keystone para a cadeia Multiple/XAMR900
  — é mecânico (keystone→multiple, xamr100→xamr900)
- **(b)** Ajuda para rodar o teste E2E no RADD e interpretar resultados
- **(c)** Fazer a verificação RCS RADD vs RADP que o Julian pediu
- **(d)** Continuar pendências (xam080? outros scripts? número da story?)

Todos os arquivos estão na pasta `deliverables/` dentro do workspace
"MAPP processes". Os scripts originais (não modificados) estão na raiz do
workspace para referência/diff.
