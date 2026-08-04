#!/bin/ksh
###########################################################################
# diag_radd.sh - Diagnostico do ambiente de teste ALTP/MAPP no RADD
#
# Rodar no servidor DEV dawapp7017l (RADD) como rj132422 ou race_b1.
#
# Objetivo: descobrir por que a execucao xamr900 -> xamref.ksh abortou:
#   (1) $LOG vazio na linha do sqlplus  -> ": cannot open"
#   (2) abndalrt.ksh / setgdg.ksh "not found" (fora do PATH)
#
# O script NAO altera nada. So coleta informacao. Redirecione a saida:
#   ./diag_radd.sh > diag_radd.out 2>&1
###########################################################################

echo "######################################################################"
echo "# 1. IDENTIFICACAO"
echo "######################################################################"
hostname
id
date
echo

echo "######################################################################"
echo "# 2. LOCALIZACAO DOS SCRIPTS (which) + PATH atual"
echo "######################################################################"
for s in xamr900.ksh xamref.ksh xamupd.ksh xamrpt.ksh \
         race_altp.ksh exec_restart.ksh \
         abndalrt.ksh setgdg.ksh email_rpt.ksh rpt_log_retention.ksh \
         altp_ftp_data.ksh; do
    printf "%-26s -> " "$s"
    which "$s" 2>/dev/null || echo "*** NOT FOUND no PATH ***"
done
echo
echo "PATH atual (1 por linha):"
echo "$PATH" | tr ':' '\n'
echo

echo "######################################################################"
echo "# 3. AMBIENTE APOS SOURCE DO race_altp.ksh"
echo "#    (roda em subshell - nao suja a sua sessao)"
echo "######################################################################"
(
  . race_altp.ksh 2>/dev/null
  echo "RACE        = [$RACE]"
  echo "LOG         = [$LOG]"
  echo "JOBLOGNAME  = [$JOBLOGNAME]"
  echo "JOBNAME     = [$JOBNAME]"
  echo "OBJ_TMPDIR  = [$OBJ_TMPDIR]"
  echo "OBJ_RPTDIR  = [$OBJ_RPTDIR]"
  echo "--- PATH apos source (1 por linha) ---"
  echo "$PATH" | tr ':' '\n'
)
echo

echo "######################################################################"
echo "# 4. ONDE 'LOG' E 'PATH' SAO DEFINIDOS NA CADEIA DE AMBIENTE"
echo "######################################################################"
RACE_ALTP=$(which race_altp.ksh 2>/dev/null)
if [ -n "$RACE_ALTP" ]; then
    echo "--- grep LOG|PATH|JOBLOGNAME em $RACE_ALTP ---"
    grep -nE 'LOG|PATH|JOBLOGNAME' "$RACE_ALTP"
else
    echo "race_altp.ksh NAO encontrado no PATH"
fi
echo
EXEC_RST=$(which exec_restart.ksh 2>/dev/null)
if [ -n "$EXEC_RST" ]; then
    echo "--- grep LOG|ksh_run|export|profile em $EXEC_RST ---"
    grep -nE 'LOG|ksh_run|export|\.profile' "$EXEC_RST"
else
    echo "exec_restart.ksh NAO encontrado no PATH"
fi
echo

echo "######################################################################"
echo "# 5. UTILITARIOS QUE DERAM 'NOT FOUND' - existem no disco?"
echo "#    email_rpt.ksh FOI achado no teste; abndalrt/setgdg NAO."
echo "#    Confere se os tres estao no mesmo diretorio."
echo "######################################################################"
EMAIL_PATH=$(which email_rpt.ksh 2>/dev/null)
EMAIL_DIR=$(dirname "$EMAIL_PATH" 2>/dev/null)
echo "Diretorio do email_rpt.ksh: ${EMAIL_DIR:-<nao achou no PATH>}"
if [ -n "$EMAIL_DIR" ]; then
    ls -la "$EMAIL_DIR/abndalrt.ksh" "$EMAIL_DIR/setgdg.ksh" 2>&1
fi
echo
echo "--- procurando abndalrt.ksh / setgdg.ksh nas arvores race ---"
find /mdev/race /prod/race 2>/dev/null \( -name 'abndalrt.ksh' -o -name 'setgdg.ksh' \) -print
echo

echo "######################################################################"
echo "# 6. NFS MOUNT E PASTA DE TESTE"
echo "######################################################################"
echo "--- mount (filtro nas/oemdocrep) ---"
mount | grep -i 'oemdocrep\|/nas' || echo "(nenhum mount nas/oemdocrep listado)"
echo
echo "--- df do caminho de teste ---"
df -h /nas/mdev/OEM_Repair_Doc_Repository 2>/dev/null || echo "df: caminho nao montado"
echo
echo "--- conteudo de altp/ no local de teste ---"
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/ 2>&1
echo
echo "--- subpastas esperadas ---"
ls -ld /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/NAPA \
       /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/Internal_Rpts \
       /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/Customer_Rpts 2>&1
echo

echo "######################################################################"
echo "# 7. RUN-FILE DA ULTIMA EXECUCAO (se ainda existir em /tmp)"
echo "######################################################################"
if [ -f /tmp/xamr900_xamref.ksh_run ]; then
    ls -la /tmp/xamr900_xamref.ksh_run
    echo "--- primeiras 30 linhas ---"
    head -30 /tmp/xamr900_xamref.ksh_run
else
    echo "(run-file /tmp/xamr900_xamref.ksh_run nao existe mais)"
fi
echo

echo "######################################################################"
echo "# 8. VERSAO DOS 4 ARQUIVOS NO altp/bin (confirmar o que esta deployado)"
echo "######################################################################"
ALTP_BIN=$(dirname "$(which xamref.ksh 2>/dev/null)" 2>/dev/null)
echo "altp/bin = ${ALTP_BIN:-<nao achou xamref.ksh no PATH>}"
if [ -n "$ALTP_BIN" ]; then
    for f in altp_ftp_data.ksh xamref.ksh xamupd.ksh xamrpt.ksh; do
        printf "%-22s " "$f"
        ls -la "$ALTP_BIN/$f" 2>&1
    done
fi
echo

echo "######################################################################"
echo "# FIM DO DIAGNOSTICO"
echo "######################################################################"
