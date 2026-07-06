==============================================================================
 okToGO - deliverables mptr299 + mptr300 (migracao AIX/prod3nt -> Linux/Mitchell)
 Autor das mudancas: rj132422
==============================================================================

OBJETIVO
  Rodar mptr299 e mptr300 com sucesso SEM prod3nt. O handoff 299->300 passa
  pelo Mitchell ftp-ssh, em /prod/data/ftp/Business_Partners/mitchell/<lvl>/oem/incoming.

ARQUIVOS (deploy no share/bin do RACE, mesmo local dos originais)
  1) oem_ref_mptr299_ftp_tesla_source_file.ksh   (driver do mptr299)
       - Step040/050/060: entrega dos 3 .dat trocada de fileput.exp(prod3nt)
         para 'scp' pro Mitchell (NT_DIR = ${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem/incoming).
         Verificacao passou a comparar a contagem de bytes no destino via ssh.
       - Step020R (zip -> oem_research, ERA Editorial no prod3nt): DESLIGADO
         (guard 'if false'), pendente definir novo destino do Editorial.
       - Step999R: cleanup do /tmp reativado (comportamento normal de prod).

  2) oem_job_process_mitchell_ftp_file.ksh       (compartilhado 299 e 300)
       - GETMIT no MATCH EXATO original (revertida a versao "latest+rename",
         que era so pro zip da Tesla e quebrava o mptr300).

  3) oem_job_datafile_prep.ksh                   (compartilhado)
       - Opcao 4 roteia para GETMIT (le do Mitchell), no lugar do fileget.ksh/prod3nt.

  4) raceftp.ksh
       - FTP_MITCHELL_BUSINESS_PATH=/prod/data/ftp/Business_Partners/mitchell

FLUXO RESULTANTE
  mptr299: fetch -> unzip -> scp dos 3 .dat pro Mitchell incoming
           (mptr299_raw_tesla_price.dat / _super.dat / _catlg.dat)
  mptr300: Opcao 4 GETMIT -> le os mesmos 3 .dat do Mitchell incoming -> reformat
  (Confirmado 1:1 no log de dev do mptr300 ja sem prod3nt.)

PRE-REQUISITOS
  - Conectividade/chave ssh do host de dev/prod para ftp-ssh.mitchell.com (ja validada em dev).
  - Tirar CRLF antes de rodar:  sed -i 's/\r$//' *.ksh
  - Tabela oem_job_datafile:
      mptr299: FTP_PROGRAM_NAME nulo; entrada da Tesla via Opcao 2/nome exato.
      mptr300: FTP_PROGRAM_NAME nulo, FTP_LOCATION_CODE=N (-> Opcao 4/GETMIT).

PENDENCIAS (fora do escopo de "rodar 299 e 300")
  - Editorial (Step020R): definir novo destino do zip no lugar de \\prod3nt\...\oem_research.
==============================================================================
