#!/bin/ksh
#$Id: racekshrc.ksh,v 1.5 2007/05/09 13:04:56 lm5200 Exp $
###########################################################################
#
#   DESCRIPTION
#   Called by raceprofile.ksh to build environment variables and alias
#
#   05/08/2007 LM  1) Changed:
#                     - 'oto' aliases to point to 'oem'
#                  2) Deleted:
#                     - 'p' aliases (pbin, pdat, etc)           
#                     - all aliases using rsh 
#                     - references to qrp lib and inc dirs
#                     - sort alias (no longer need to redirect output to /tmp).
#   10/24/2006 JLW Changed /parts to /oem as part of the IBM migration project.
#   08/18/2006 JLW Removed references to /$ACT_LVL/race/misc directories
#                  Added references /$ACT_LVL/race/oto/prm directory
#                  Removed duplicated statements in section "shared COBOL stuff"
#                  Added alias' for new machines and removed old machines
#
###########################################################################

########## race logicals and aliases #########
export abin=/$ACT_LVL/race/altp/bin
export adat=/$ACT_LVL/race/altp/dat
export adoc=/$ACT_LVL/race/altp/doc
export alog=/$ACT_LVL/race/altp/log
export aprm=/$ACT_LVL/race/altp/prm
export arpt=/$ACT_LVL/race/altp/rpt
export asrc=/$ACT_LVL/race/altp/src
export atmp=/$ACT_LVL/race/altp/tmp
#
export cbin=/$ACT_LVL/race/ceg/bin
export cdat=/$ACT_LVL/race/ceg/dat
export cdoc=/$ACT_LVL/race/ceg/doc
export clog=/$ACT_LVL/race/ceg/log
export cprm=/$ACT_LVL/race/ceg/prm
export crpt=/$ACT_LVL/race/ceg/rpt
export csrc=/$ACT_LVL/race/ceg/src
export ctmp=/$ACT_LVL/race/ceg/tmp
#
export ebin=/$ACT_LVL/race/ext/bin
export edat=/$ACT_LVL/race/ext/dat
export edoc=/$ACT_LVL/race/ext/doc
export elog=/$ACT_LVL/race/ext/log
export eprm=/$ACT_LVL/race/ext/prm
export erpt=/$ACT_LVL/race/ext/rpt
export esrc=/$ACT_LVL/race/ext/src
export etmp=/$ACT_LVL/race/ext/tmp
#
export obin=/$ACT_LVL/race/oem/bin
export odat=/$ACT_LVL/race/oem/dat
export odoc=/$ACT_LVL/race/oem/doc
export olog=/$ACT_LVL/race/oem/log
export oprm=/$ACT_LVL/race/oem/prm
export orpt=/$ACT_LVL/race/oem/rpt
export osrc=/$ACT_LVL/race/oem/src
export otmp=/$ACT_LVL/race/oem/tmp
#
export qbin=/$ACT_LVL/race/qrp/bin
export qdat=/$ACT_LVL/race/qrp/dat
export qdoc=/$ACT_LVL/race/qrp/doc
export qlog=/$ACT_LVL/race/qrp/log
export qprm=/$ACT_LVL/race/qrp/prm
export qrpt=/$ACT_LVL/race/qrp/rpt
export qsrc=/$ACT_LVL/race/qrp/src
export qtmp=/$ACT_LVL/race/qrp/tmp
#
export sbin=/$ACT_LVL/race/share/bin
export sdat=/$ACT_LVL/race/share/dat
export sdoc=/$ACT_LVL/race/share/doc
export sinc=/$ACT_LVL/race/share/inc
export slib=/$ACT_LVL/race/share/lib
export slog=/$ACT_LVL/race/share/log
export sprm=/$ACT_LVL/race/share/prm
export srpt=/$ACT_LVL/race/share/rpt
export ssrc=/$ACT_LVL/race/share/src
export stmp=/$ACT_LVL/race/share/tmp
#
alias abin="cd $abin"
alias adat="cd $adat"
alias adoc="cd $adoc"
alias alog="cd $alog"
alias aprm="cd $aprm"
alias arpt="cd $arpt"
alias asrc="cd $asrc"
alias atmp="cd $atmp"
#
alias cbin="cd $cbin"
alias cdat="cd $cdat"
alias cdoc="cd $cdoc"
alias clog="cd $clog"
alias cprm="cd $cprm"
alias crpt="cd $crpt"
alias csrc="cd $csrc"
alias ctmp="cd $ctmp"
#
alias ebin="cd $ebin"
alias edat="cd $edat"
alias edoc="cd $edoc"
alias elog="cd $elog"
alias eprm="cd $eprm"
alias erpt="cd $erpt"
alias esrc="cd $esrc"
alias etmp="cd $etmp"
#
alias obin="cd $obin"
alias odat="cd $odat"
alias odoc="cd $odoc"
alias olog="cd $olog"
alias oprm="cd $oprm"
alias orpt="cd $orpt"
alias osrc="cd $osrc"
alias otmp="cd $otmp"
#
alias qbin="cd $qbin"
alias qdat="cd $qdat"
alias qdoc="cd $qdoc"
alias qlog="cd $qlog"
alias qprm="cd $qprm"
alias qrpt="cd $qrpt"
alias qsrc="cd $qsrc"
alias qtmp="cd $qtmp"
#
alias sbin="cd $sbin"
alias sdat="cd $sdat"
alias sdoc="cd $sdoc"
alias sinc="cd $sinc"
alias slib="cd $slib"
alias slog="cd $slog"
alias sprm="cd $sprm"
alias srpt="cd $srpt"
alias ssrc="cd $ssrc"
alias stmp="cd $stmp"
#
export stage_abin=/stage/race/altp/bin
export stage_aprm=/stage/race/altp/prm
export stage_asrc=/stage/race/altp/src
export stage_cbin=/stage/race/ceg/bin
export stage_cprm=/stage/race/ceg/prm
export stage_csrc=/stage/race/ceg/src
export stage_obin=/stage/race/oem/bin
export stage_oprm=/stage/race/oem/prm
export stage_osrc=/stage/race/oem/src
export stage_qbin=/stage/race/qrp/bin
export stage_qprm=/stage/race/qrp/prm
export stage_qsrc=/stage/race/qrp/src
export stage_sbin=/stage/race/share/bin
export stage_sinc=/stage/race/share/inc
export stage_slib=/stage/race/share/lib
export stage_sprm=/stage/race/share/prm
export stage_ssrc=/stage/race/share/src
#
alias stage_abin="cd $stage_abin"
alias stage_aprm="cd $stage_aprm"
alias stage_asrc="cd $stage_asrc"
alias stage_cbin="cd $stage_cbin"
alias stage_cprm="cd $stage_cprm"
alias stage_csrc="cd $stage_csrc"
alias stage_obin="cd $stage_obin"
alias stage_oprm="cd $stage_oprm"
alias stage_osrc="cd $stage_osrc"
alias stage_qbin="cd $stage_qbin"
alias stage_qprm="cd $stage_qprm"
alias stage_qsrc="cd $stage_qsrc"
alias stage_sbin="cd $stage_sbin"
alias stage_sinc="cd $stage_sinc"
alias stage_slib="cd $stage_slib"
alias stage_ssrc="cd $stage_ssrc"
#
########## unix aliases ##########
alias d='ls -aF'
alias rm='echo \    uh, use rmi '
alias rmi='/bin/rm -i'
alias vi='stty erase ^?;/usr/bin/vi'
alias hogs='ps aux | head -10'


###########################################################################
# END racekshrc.ksh
###########################################################################
