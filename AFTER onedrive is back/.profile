#PS1='$USER:$PWD> '
# rj132422 - prompt fundo red, texto white
#PS1="$(printf '\033[1;97;41m')"'$USER:$PWD> '"$(printf '\033[0m')"

export #SQLPATH=/home/rj132422

set -o emacs

# ##########################################
# shortcut commands
# ##########################################
alias lt='ls -lt'
alias lh='ls -lt |head -30'
alias lhj='ls -lt |grep rj132422|cut -c30-100| head -30'
alias cp='cp -i '
alias mv='mv -i '
alias cls='clear'
alias exit='sh $HOME/.logout;exit'
alias dr='ls -lt|grep drw'
alias running='ps -aef | grep rj132422'

export EXINIT="set ic"
EXINIT="set ic"

export ACT_LVL=prod
. /$ACT_LVL/race/share/bin/raceprofile.ksh

HOST=$(hostname -s)
PS1="$(printf '\033[1;97;41m')"'$USER@$HOST:$PWD> '"$(printf '\033[0m')"

export LIBPATH=$LIBPATH/opt/ruby241/lib:/opt/freeware/lib
export PATH=$PATH:.:/opt/ruby241:/opt/ruby241/bin

set -o noclobber

ulimit -d 2000000

unalias rm

# ##########################################
# Get arrow keys working in emacs mode
# ##########################################
alias __A=`echo "\020"` # up arrow = ^p = back a command
alias __B=`echo "\016"` # down arrow = ^n = down a command
alias __C=`echo "\006"` # right arrow = ^f = forward a character
alias __D=`echo "\002"` # left arrow = ^b = back a character
alias __H=`echo "\001"` # home = ^a = start of line

#echo "\n\n\nBe quick to listen, slow to speak, slow to anger."
#echo "--- James \n\n\n"
echo "Rodrigo you're logged in!"

#export ORACLE_LD_LIBRARY_PATH=/usr/lib/oracle/23/client64/lib:/u01/app/oracle/product/23/client64/lib
export PATH=/prod/race/share/bin:/usr/lib/oracle/23/client64/bin:/u01/app/oracle/product/23/client64/bin:/root/.local/bin:/root/bin:/sbin:/bin:/usr/sbin:/usr/bin:/prod/util/share/bin:/opt/microfocus/cobol/bin:/usr/local/bin:/stage/race/share/bin
#export TNS_ADMIN=/usr/lib/oracle/23/client64/lib/network/admin
export TWO_TASK=RADP.MITCHELL.COM


export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME/bin:$PATH

export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin
export PATH=/opt/rocketsoftware/VisualCOBOL/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocketsoftware/VisualCOBOL/lib:$LD_LIBRARY_PATH
export COBCPY="/prod/race/share/inc:/prod/race/share/inc/rollback:/prod/race/oem/inc:/prod/race/oem/../share/inc"
export LIBPATH=/opt/rocketsoftware/VisualCOBOL/lib:$LD_LIBRARY_PATH
export TWO_TASK=RADP.MITCHELL.COM
export ORACLE_SID=RADP.MITCHELL.COM
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME/bin:$PATH
 . /opt/rocketsoftware/VisualCOBOL/bin/cobsetenv


export PATH=/opt/rocketsoftware/VisualCOBOL/bin:/u01/app/oracle/product/19.3.0/client64/bin:/prod/race/share/bin:/prod/race/oem/bin:/usr/lib/oracle/23/client64/bin:/etc:/root/.local/bin:/root/bin:/sbin:/bin:/usr/sbin:/usr/bin:/prod/util/share/bin:/opt/microfocus/cobol/bin:/usr/local/bin:/stage/race/share/bin:/stage/race/oem/bin

 CLEANED_USER=$(echo $LOGNAME | sed 's/@.*//')
 export LOGNAME=$CLEANED_USER
