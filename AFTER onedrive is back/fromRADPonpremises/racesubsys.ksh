#!/bin/ksh
#$Id: racesubsys.ksh,v 1.4 2007/05/09 13:05:22 lm5200 Exp $
##############################################################################
#
#   DESCRIPTION
#   Called by raceprofile.ksh to build development RACE subsystem environment
#
#   05/01/2007 LM  Removed references to 'oto'.
#   10/24/2006 JLW Changed /parts to /oem as part of the IBM migration project.
#
##############################################################################

trap "" 2

if [ $ACT_LVL = "prod" -o $ACT_LVL = "mdev" ]
then
   if [ $ACT_LVL = "prod" ]
   then
      VSID=radp
   else
      VSID=radd
   fi
else
   echo " "
   echo "environment variable ACT_LVL should be prod or mdev"
   echo " "
   echo "\$ACT_LVL is set to --> $ACT_LVL"
   echo " "
   echo "Check script /etc/profile and verify value"
   echo "Press enter to continue... \c"
   read PAUSE
fi

echo "ACTIVITY LEVEL is $ACT_LVL"
echo
echo "DATABASE (ORACLE_SID) is $VSID"
echo " "

SUBOK=''
while [[ -z $SUBOK ]]
do
    echo " "
    echo "Select one of race subsystems:"
    echo "1) ceg "
    echo "2) oem "
    echo "3) altp "
    echo "4) share "
    echo "5) ext "
    echo "6) qrp "
    echo ""
    read SUBSID?"Type subsystem id (1, 2, 3, 4, 5, 6)? "

    case $SUBSID in
    1|ceg) SUBSYS=ceg;SUBOK='OK';;
    2|oem) SUBSYS=oem;SUBOK='OK';;
    3|altp) SUBSYS=altp;SUBOK='OK';;
    4|share) SUBSYS=share;SUBOK='OK';;
    5|ext) SUBSYS=ext;SUBOK='OK';;
    6|qrp) SUBSYS=qrp;SUBOK='OK';;
    *)
        echo "\n \07 Typed invalid $SUBSID subsystem id try again ! \07 \n"
        ;;
   esac
done

export RACE=/$ACT_LVL/race/$( echo $SUBSYS | awk '{print tolower($0)}')
export APPSYS=$SUBSYS
echo " "

newsid $VSID

echo " "
echo "============================================================"
echo " System \$ACT_LVL    variable is set to $ACT_LVL"
echo " System \$RACE       variable is set to $RACE"
echo " System \$STAGE      variable is set to $STAGE"
echo " Oracle \$ORACLE_SID instance is set to $ORACLE_SID"
echo "============================================================"

trap 2

###########################################################################
# END racesubsys.ksh
###########################################################################
