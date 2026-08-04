#!/bin/ksh
#$Id: setgdg.ksh,v 1.4 2017/06/30 22:40:01 jl101765 Exp $
###########################################################################
#
#   DESCRIPTION
#     This script returns the next '*.g00' number of a given file name.
#
#   EXAMPLE
#     setGDG filename [NEW] [cycles]
#        i.e setGDG afile(+1) NEW 3
#
#   FILES
#     setGDG_awk        - setGDG support 'awk' file
#
#   RETURN
#
# 2006/08/09 JLW Script modified to run on either PROD or MDEV using $ACT_LVL
#
###########################################################################

AWK=/$ACT_LVL/race/share/bin/setgdg.awk # set <fname>_awk for awk file

if [[ $# = "0" ]]                  # test for arguments
then
  exit -1
fi

if [[ $# = "1" ]]                  # test for more than 1 argument
then
   DISP=""
else
   DISP=$2                         # set DISP to 2nd argument
fi

Afile=$(echo $1 | awk -f$AWK -vDISP=$DISP -vTfile=.setGDG$PPID) 2>/dev/null

#adjust if g100
if [[ $DISP = "NEW"  ||  $DISP = "new" ]]
then
  EXT="."$( echo $Afile | awk -F "." '{ print $NF }' )
  if [[ $EXT = ".g100" ]]
  then
    BASE=${Afile%%$EXT}
    cnt=1
    for I in $( ls ${Afile%%.g*}.g?? )
    do
      Afile=$BASE".g"$(printf "%2.2d" $cnt)
      mv $I $Afile
      (( cnt=cnt + 1 ))
    done
    Afile=$BASE".g"$(printf "%2.2d" $cnt)
  fi
fi

echo $Afile                        # return g00 name of file

if ! [[ $DISP = "NEW"  ||  $DISP = "new" ]]
then
  exit                             # exit process if not NEW
fi

if [[ $( echo $Afile | awk -F "." '{ print $NF }' ) = "g01" ]]
then
  exit 0                           # exit if first g01
fi

if [[ $# > "2"  ]]
then
  if [[ $3 > "0" ]]                # if retention count, remove
  then                             # those files greate than the count
     (( cnt=$3 - 1 ))
     for I in $( ls -r $(echo $Afile | awk '{print substr($0,1,length-2)"??"}'))
     do
       if [[ cnt -le 0 ]]
       then
         rm -f $I                     # remove file
       else
         (( cnt=cnt - 1 ))
       fi
     done
  fi
fi

exit 0

###########################################################################
# END setgdg.ksh
###########################################################################
