PS1='$USER:$PWD> '

set -o emacs

# ##########################################
# shortcut commands
# ##########################################
alias lt='ls -lt'
alias lh='ls -lt |head -30'
alias cp='cp -i '
alias mv='mv -i '
alias cls='clear'
alias exit='sh $HOME/.logout;exit'
alias dr='ls -lt|grep drw'

export EXINIT="set ic"
EXINIT="set ic"

# User specific environment and startup programs
export HOSTNAME=`/usr/bin/hostname 2>/dev/null`
export ACT_LVL=prod
export PATH=$HOME/bin:/usr/local/bin/perl:.:$PATH
export SRVR=`hostname`
export SERVER_NAME=`hostname`
export FTP_MITCHELL_BUSINESS_PATH=/$ACT_LVL/data/ftp/Business_Partners/mitchell
export PATH=$HOME:/usr/lib/oracle/23/client64/bin:/etc:/root/.local/bin:/root/bin:/sbin:/bin:/usr/sbin:/usr/bin:/prod/util/share/bin:/opt/microfocus/cobol/bin:/usr/local/bin:/prod/race/share/bin:/prod/race/bin:/prod/race/ext/bin:/stage/race/share/bin:/stage/race/ext/bin:

# BEGIN ORACLE ENVIRONMENT
umask 022
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_HOSTNAME=pawapp7017l
export ORA_INVENTORY=/u01/app/oraInventory
export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin
export TWO_TASK=RADP.MITCHELL.COM
export ORACLE_SID=RADP.MITCHELL.COM
# END ORACLE ENVIRONMENT
. /$ACT_LVL/race/share/bin/raceprofile.ksh
export LIBPATH=$LIBPATH/opt/ruby241/lib:/opt/freeware/lib
export PATH=$PATH:.:/opt/ruby241:/opt/ruby241/bin

set -o noclobber

ulimit -d 2000000

unalias rm

unset CMD_ENV

# ##########################################
# Get arrow keys working in emacs mode
# ##########################################

alias __A=`echo "\020"` # up arrow = ^p = back a command
alias __B=`echo "\016"` # down arrow = ^n = down a command
alias __C=`echo "\006"` # right arrow = ^f = forward a character
alias __D=`echo "\002"` # left arrow = ^b = back a character
alias __H=`echo "\001"` # home = ^a = start of line

echo "You are logged in!"


