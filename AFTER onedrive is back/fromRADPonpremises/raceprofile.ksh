#!/bin/ksh
#$Id: raceprofile.ksh,v 1.5 2016/05/04 21:49:03 pg2697 Exp $
###############################################################################
#
#   DESCRIPTION
#   Called by developers .profile to build development environment for RACE
#
# 2016/05/03 PAG Commented out SPF-related commands. SPF-UX is no longer used.
###############################################################################

export TERM=vt100
stty -crterase
stty -tabs
stty crt
stty erase '^h'
stty werase '^?'

if [ ! "$DT" ]; then
    stty dec
    tset -I -Q
fi

set -o emacs
alias __A="^P"
alias __B="^N"
alias __C="^F"
alias __D="^B"
tset -I -Q

export STAGE=/stage/race
export NOVELL=$ACT_LVL/

. /$ACT_LVL/race/share/bin/raceftp.ksh

export RCSHOST=race
if [ $THISHOST = $PRODHOST ]
then
   export RCSDIR=/prod/race
else
   export RCSDIR=$RCSHOST:/prod/race
fi

. /$ACT_LVL/race/share/bin/racesubsys.ksh

PATH=$PATH:/usr/bin/X11:/usr/lib/cobol/bin:/usr/local/spfux/decbin:.\
:/$ACT_LVL/race/share/bin:/$ACT_LVL/race/bin:$RACE/bin\
:$STAGE/share/bin:$STAGE/$APPSYS/bin

export PATH
SYSNAME=$(hostname -s)
PS1='$SYSNAME($ORACLE_SID):$PWD> '

#export SPFPATH=/usr/local/spfux
#alias  spf='TERM=vt220;spfux'

export ENV=/$ACT_LVL/race/share/bin/racekshrc.ksh

alias toolbox='TERM=xterm; tbox; TERM=vt100'

umask 002
set -o ignoreeof
export CMD_ENV=bsd

export MANPATH=$MANPATH:usr/share/man:/$ACT_LVL/race/share/doc/man:/opt/freeware/man

if [[ -a ~/.userprofile ]]
then
    . ~/.userprofile
fi

###########################################################################
# END raceprofile.ksh
###########################################################################
