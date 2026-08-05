# As-is / To-be — Ambiente DEV (RADD / mdev)

Data: 2026-04-24 (atualizado)
Autor: Rodrigo Jasinski
Story: AES-XXXX
Servidor DEV: RADD (dawapp7017l)

---

## IMPORTANTE — os 3 estados do caminho de arquivos

O caminho onde os arquivos MAPP/ALTP moram passou por mais de uma definição.
Hoje existem **três estados** e é essencial não confundi-los:

| Estado | Caminho | Situação |
|---|---|---|
| **1. AS-IS (hoje)** | `\\prod3nt\cdprod02\ftp_data\mdev\altp\` via `${NOVELL}` | Em produção. prod3nt vai ser decommissioned. |
| **2. TO-BE temporário (teste AGORA)** | `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev` | Subpasta dentro de um mount NFS que JA EXISTE. Usado nos testes E2E enquanto o folder definitivo nao e decidido. |
| **3. TO-BE final** | **ainda nao decidido** | Candidato discutido: `/nas/ftp_data/mdev`. Aguardando decisao do Julian / Ops. |

> **Por que isso nao bloqueia o trabalho:** os scripts NAO tem caminho
> hard-coded. Todos leem a variavel `ALTP_FTP_DATA` do arquivo de config
> `altp_ftp_data.ksh`. Mudar de estado 2 para estado 3 = trocar UMA linha
> nesse arquivo. Os 9 scripts nao precisam ser tocados de novo.

Nas tabelas abaixo, a coluna TO-BE mostra o **estado 2 (temporario)**, que e
o que vai ser efetivamente usado nos testes. Onde o caminho final (estado 3)
for confirmado, basta atualizar `altp_ftp_data.ksh`.

---

## 1. Servidor de armazenamento

| Atributo | AS-IS (hoje) | TO-BE (depois da migração) |
|---|---|---|
| Tipo de servidor | Windows + Novell, acessado via FTP/SMB | NFS server na AWS |
| Hostname | `prod3nt.production.int` | `dawsvm7001a.staging.int` (mesmo NFS server que serve o OEM_Repair_Doc_Repository e o /mdev/race) |
| Protocolo de acesso pelo Linux | FTP via `fileget.exp` / `fileput.exp` | NFS v4 (mount local) |
| Acesso pelo Windows (Chuck/analista) | Mapeado como drive `S:` | A confirmar - possivelmente SMB sobre o mesmo NFS |
| Vai ser desligado? | **Sim** - nao migra pra AWS | - |

---

## 2. Mount / endereço base no script server Linux

| Atributo | AS-IS | TO-BE temporário (teste) | TO-BE final |
|---|---|---|---|
| Caminho base | `${NOVELL}` via `fileget.exp`/`fileput.exp` (prod3nt) | `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev` | a decidir (ex: `/nas/ftp_data/mdev`) |
| Precisa de mount novo? | - | **Nao** - reusa o mount NFS ja existente `/nas/mdev/OEM_Repair_Doc_Repository` | **Sim** - mount dedicado via SCTASK |
| Onde a config vive | Variavel `${NOVELL}` no profile do batch | Arquivo `altp_ftp_data.ksh` (variavel `ALTP_FTP_DATA`) | mesmo arquivo `altp_ftp_data.ksh` |
| Visivel em `df -h`? | Nao | Sim - `dawsvm7001a.staging.int:/oemdocrepsharedev ... /nas/mdev/OEM_Repair_Doc_Repository` | Sim - linha propria |

---

## 3. Variáveis de ambiente / configuração

| Variável | AS-IS | TO-BE |
|---|---|---|
| `${NOVELL}` | Caminho FTP que aponta pra `\\prod3nt\cdprod02\ftp_data\mdev\` | **Nao e mais usada pelos scripts ALTP.** Pode continuar definida pra outros scripts nao-ALTP. |
| `ALTP_FTP_DATA` | Nao existia | **NOVA.** Definida em `altp_ftp_data.ksh`. Estado 2: `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev`. Estado 3: a decidir. |
| `ALTP_DIR` / `ALTP_NAPA_DIR` / `ALTP_INTRPT_DIR` / `ALTP_CUSTRPT_DIR` | Nao existiam | **NOVAS.** Derivadas de `ALTP_FTP_DATA` no proprio `altp_ftp_data.ksh`. |
| `${FTP_SITE}` / `${FTP_BUSINESS_PATH}` / `${FTP_MITCHELL_BUSINESS_PATH}` | Definidas em `raceftp.ksh` | **Sem mudanca** - usadas por outros fluxos, nao pelo ALTP migrado |

---

## 4. Estrutura de pastas usada pelos scripts ALTP

### 4.1 Pastas

| Uso da pasta | AS-IS (prod3nt) | TO-BE (dentro de `${ALTP_FTP_DATA}`) | Variavel no codigo |
|---|---|---|---|
| Base ALTP | `${NOVELL}altp` | `${ALTP_FTP_DATA}/altp/` | `${ALTP_DIR}` |
| NAPA especifico | `${NOVELL}altp/NAPA` | `${ALTP_FTP_DATA}/altp/NAPA/` | `${ALTP_NAPA_DIR}` |
| Relatorios internos | `${NOVELL}altp/Internal_Rpts` | `${ALTP_FTP_DATA}/altp/Internal_Rpts/` | `${ALTP_INTRPT_DIR}` |
| Relatorios pra cliente | `${NOVELL}altp/Customer_Rpts` | `${ALTP_FTP_DATA}/altp/Customer_Rpts/` | `${ALTP_CUSTRPT_DIR}` |
| Race shared | `${NOVELL}race` | **Fora do escopo desta task** - fica como esta | - |

> No estado 2 (teste), `${ALTP_FTP_DATA}` = `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev`,
> entao `${ALTP_DIR}` = `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/` etc.

### 4.2 Onde cada arquivo principal mora

| Arquivo | AS-IS | TO-BE (variavel) |
|---|---|---|
| `keystone_combined.txt` / `multiple_combined.txt` (input do Chuck) | `${NOVELL}altp` | `${ALTP_DIR}` |
| `napa_combined.txt` (gerado por xam200) | `${NOVELL}altp` | `${ALTP_DIR}` |
| `*_refproc.txt` / `*_rpt_prov.txt` (round-trip) | `${NOVELL}altp` | `${ALTP_DIR}` |
| `del_supplier_list.txt` / `copy_supplier.txt` / `capacert.prn` | `${NOVELL}altp` | `${ALTP_DIR}` |
| `COL.hdr` / `COLNW.hdr` / `col.txt` / `colnw.txt` / `CollisionFromNapa.zip` | `${NOVELL}altp/NAPA` | `${ALTP_NAPA_DIR}` |
| `*_referrs.txt` / `*_refsum.rpt` / `*_partver_sum.txt` / `*_updt_sum.txt` / `cat_dtl.rpt` / `noclssum.rpt` | `${NOVELL}altp/Internal_Rpts` | `${ALTP_INTRPT_DIR}` |
| `category.rpt` | `${NOVELL}altp/Customer_Rpts` | `${ALTP_CUSTRPT_DIR}` |
| `Mitchell_CollisionFromNAPA*.zip` (upload da NAPA) | `$FTP_BUSINESS_PATH/NAPA/mdev/incoming/` (FTP Mitchell) | **Sem mudanca** - continua no FTP Mitchell |
| `mitch_exc_rpts.zip` (saida pros suppliers) | `$FTP_BUSINESS_PATH/$QUALIFIER/mdev/outgoing/` (FTP Mitchell) | **Sem mudanca** - continua no FTP Mitchell |

---

## 5. Mecanismo de acesso a arquivos dentro dos scripts

| Operação | AS-IS | TO-BE |
|---|---|---|
| Ler arquivo (binario) | `fileget.exp $f $u $d` | `cp ${d}/${f} ${u}` + verificacao `wc -c` |
| Ler arquivo (modo ascii) | `fileget.exp $f $u $d ascii` | `cp` + `tr -d '\r'` (CRLF -> LF) |
| Escrever arquivo (modo ascii) | `fileput.exp $f nome $d ascii` | `sed 's/\r*$/\r/' $f > ${d}/nome` (LF -> CRLF) |
| Verificar byte count | `grep 'Information ret' $LOG` | `wc -c` direto nos arquivos locais |
| Procedure compartilhada (`fileget.exp`/`fileput.exp`) | Usada por dezenas de scripts | **Nao tocar** - outros scripts ainda dependem |

---

## 6. Permissões e usuários

| Item | AS-IS | TO-BE |
|---|---|---|
| Usuários | `race_b1`, `rj132422` | `race_b1`, `rj132422` |
| Permissão necessária | Read/write no share prod3nt | Read/write em `${ALTP_FTP_DATA}` |
| Estado 2 (teste) | - | Permissao no mount `/nas/mdev/OEM_Repair_Doc_Repository` (ja existe - confirmar write) |
| Estado 3 (final) | - | Permissao no mount dedicado - solicitada via SCTASK |

---

## 7. Scripts a editar (status atual)

| Script | Status |
|---|---|
| `xamref.ksh`, `xamupd.ksh`, `xamrpt.ksh` | **FEITO** - cadeia Keystone |
| `xam200.ksh`, `xam010.ksh`, `xam001.ksh`, `xam030.ksh`, `xam069.ksh` | **FEITO** - NAPA + auxiliares |
| `xamr200.ksh` | **FEITO** - 1 fix AIX->RHEL |
| `altp_ftp_data.ksh` | **FEITO** - config nova |
| Wrappers `xamr100/101/102/201/202/900/901/902/001/010/030/069` | **Sem mudanca** - ja eram RHEL-clean |

---

## 8. Tickets / dependências externas

| Item | Estado | Quem provê |
|---|---|---|
| Subpasta `ftpdata/mdev/altp/...` dentro do mount OEM existente (estado 2) | A criar - `setup_test_env.sh` faz isso | Voce, no RADD |
| Mount NFS dedicado (estado 3) | **Aguardando decisao do folder final** - SCTASK rascunhado mas NAO submeter ainda | Ops (CORP-IS-Unix-Middleware-Operations) |
| Migracao dos dados de prod3nt pro novo mount | A combinar | Ops / Chuck |
| `Combine_Stage.bat` do Chuck (prod4nt) | **Task separada** - fora do escopo | Time Windows |

---

## 9. Resumo

> **AS-IS:** scripts ALTP leem/escrevem no prod3nt via FTP (`fileget.exp`/`fileput.exp`, variavel `${NOVELL}`).
>
> **TO-BE:** scripts leem/escrevem num caminho NFS local via `cp`/`sed`/`tr`, definido pela variavel `ALTP_FTP_DATA` no arquivo `altp_ftp_data.ksh`.
>
> **Agora (estado 2):** `ALTP_FTP_DATA` aponta pro temporario `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev` - reusa mount existente, sem ticket.
>
> **Depois (estado 3):** quando o folder definitivo for decidido, troca-se UMA linha em `altp_ftp_data.ksh`. Nenhum dos 9 scripts precisa ser editado de novo.
