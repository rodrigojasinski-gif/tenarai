#############################################################################################
#
# Adapted race_b1 .profile to svc-apd-race-prd@production.int service account
#
# History
#    2006/09/28 JLW      IBM 10g Migration Project
#    rj132422            AIX -> RHEL/AWS: Oracle env + ORACLE_SID (was newsid), MAIL path
#
#############################################################################################

#----------------------------------------------------------------------------
# The following statement is required by COS/Batch Race Suites
export ACT_LVL=prod
export act_lvl=$ACT_LVL
#----------------------------------------------------------------------------

#MAIL=/usr/spool/mail/$USER
export MAIL=/var/spool/mail/$USER

export PATH=$HOME/bin:${PATH:-/usr/bin}

# --- Oracle (RHEL/AWS) ---
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export TNS_ADMIN=$ORACLE_HOME/network/admin
export TWO_TASK=RADP.MITCHELL.COM
export ORACLE_SID=RADP.MITCHELL.COM
export PATH=$ORACLE_HOME/bin:/usr/lib/oracle/23/client64/bin:/opt/microfocus/cobol/bin:$PATH

#--------------------------------------------------------------------------------------------
# Determine if .profile has been invoked by a terminal (interactively)
#        OR from batch / ActiveBatch (no controlling terminal)
#--------------------------------------------------------------------------------------------
#############################################################################################
# NOTE: This "if [ -t 0 ]" also used as a compare string in /usr/local/bin/run_remote_command
#       IF this string changes it must also be changed in run_remote_command!!
#############################################################################################
if [ -t 0 ]
then
   echo $(date) " - Setting terminal related environment variables."
   stty dec
   stty -crterase
   stty -tabs
   stty crt
   stty erase '^h'
   stty werase '^?'
   set -o emacs
   tset -I -Q
   PS1=$(hostname -s)':$PWD> '
   echo $(date) " - Terminal related environment variables have been set."
fi

export PATH=$PATH:/$ACT_LVL/race/share/bin:/stage/race/share/bin

export RACE=/$ACT_LVL/race
export RACE_HOST=race
#VSID=radp
#newsid radp # not necessary to setup DB anymore
umask 002

# RACE env + raceftp (sets FTP_SFTP_USER / FTP_SITE / FTP_MITCHELL_BUSINESS_PATH)
. /$ACT_LVL/race/share/bin/raceprofile.ksh

alias dr='ls -l|grep drw'
alias l='ls -l |pg'
alias lt='ls -lt|pg'
## get arrows working in emacs mode
set -o emacs
alias __A=`echo "\020"` # up arrow = ^p = back a command
alias __B=`echo "\016"` # down arrow = ^n = down a command
alias __C=`echo "\006"` # right arrow = ^f = forward a character
alias __D=`echo "\002"` # left arrow = ^b = back a character
alias __H=`echo "\001"` # home = ^a = start of line
