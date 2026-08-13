# Checklist de teste — pré/pós dos scripts alterados (migração prod3nt → Mitchell)

Gerado da `job datafile.csv`. Marque `[x]` conforme testar.

## Tabela pré/pós

| # | Alterado | Papel | PRÉ (rodar/stagear antes) | PÓS (consome / rodar depois) |
|---|----------|-------|---------------------------|------------------------------|
| 1 | mptr249 | pré-proc HD | RACEOPS stagia `hdmus.zip` no **incoming** | **mptr250** |
| 2 | mptr250 | reformat HD | **mptr249** (grava no outgoing) | — saída final |
| 3 | mptr770 | editorial Frontier | `get_sftp_file.pl` traz `fntr` | Editorial (oem_research) — sem job |
| 4 | mptr799 | editorial TRP | Mitchell LOC=M `Mitchell_trp.txt` | Editorial — sem job |
| 5 | mptr825 | editorial LYNN | externo `LYNN_US_PRICE_PipeDelimited.csv` | Editorial — sem job |
| 6 | mptr829 | editorial Truck Shroud | Mitchell LOC=M `TruckShrouds_US.txt` | Editorial — sem job |
| 7 | mptr839 | pré-proc Tesla Semi | `get_sftp_file.ksh` (Tesla zip) | **mptr840** (preço+catálogo) + Editorial (zip) |
| 8 | mptr840 | reformat Tesla Semi | **mptr839** (grava no outgoing) | — saída final |
| 9 | mpt905 | distribuição de report | report gerado por um reformat | fileput do report p/ rede (só email corrigido) |
| 10 | oem_job_process_mitchell_ftp_file (GET) | shared – GET | — | usado por **mptr250** e **mptr840** (lê do outgoing) |
| 11 | oem_job_process_mitchell_ftp_file (BACKUP) | shared – BACKUP | — | jobs **LOC=M** no Step100R (ex.: mptr799, mptr829) |

## Sequência de teste

### Cadeia HD (testar em ordem)
- [ ] Stagia `hdmus.zip` no `.../mitchell/<lvl>/oem/incoming`
- [ ] Roda **mptr249** → confere `mptr249_araw_hdmus.zip` no **outgoing**
- [ ] Roda **mptr250** → confere que leu do **outgoing** (trace `FTPSITE_DIRECTORY=.../oem/outgoing`)

### Cadeia Tesla Semi (testar em ordem)
- [ ] Tesla zip chega (get_sftp_file.ksh)
- [ ] Roda **mptr839** → confere zip no **oem_research** + preço/catálogo no **outgoing**
- [ ] Roda **mptr840** → confere que leu preço/catálogo do **outgoing**

### Standalone editorial (cada um isolado)
- [ ] **mptr770** → entrega no oem_research
- [ ] **mptr799** → entrega no oem_research
- [ ] **mptr825** → entrega no oem_research
- [ ] **mptr829** → entrega no oem_research

### Outros
- [ ] **mpt905** → testar envio do e-mail (agora separado por `,`)
- [ ] **Shared BACKUP** → rodar um job LOC=M (mptr799/mptr829) até Step100R e confirmar arquivamento em `incoming/backup` sem abend
- [ ] **Shared GET** → coberto pelos testes de mptr250 e mptr840

## Notas
- Em **dev** o `FTP_SFTP_USER` é vazio (usa a conta do job); confirmar acesso SSH ao `ftp-ssh.mitchell.com`.
- Force-home pra testar sem deployar no bin: colocar o script no `$HOME` com `$HOME` na frente do PATH.
