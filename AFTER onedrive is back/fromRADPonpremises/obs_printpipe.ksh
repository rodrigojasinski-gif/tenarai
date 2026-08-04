#$Id: printpipe.ksh,v 1.1 2006/08/10 21:54:02 jw97143 Exp $
#-----------------------------------------------------------
#  printpipe                                    *02/19/96* -
#                                                          -
#    This script will -o(open), -c(close) and -r(run)      -
#    a FIFO pipe for handling direct printing requirments. -
#                                                          -
#    $1 contains the action -(dash) parameter.             -
#                                                          -
#    $2 contains the FIFO name.                            -
#                                                          -
#    $3 contains the optional output file suffix           -
#                                                          -
#-----------------------------------------------------------
function printpipe
{
  if [[ -z $COSREPORT ]]
  then
    export COSREPORT=report
  fi

  if [ $# -gt 1 ]                      # check for 2 parameters
  then
    DPARM=$1
    PNAME=$2.pip
    TOFILE=$3
    if [ $DPARM = "-o" ]               # option -o (open)
    then
#      if ! [ -a $PNAME ]
#        then
#          mkfifo $PNAME
#      fi
      if [ -a $PNAME ]
	 then 
	  rm $PNAME
      fi
      mkfifo $PNAME
      return
    else
    if [ $DPARM = "-r" ]               # option -r (run)
    then
      if [ $# -eq 3 ]
      then
        export Preport=${PNAME%%.pip}_$(date +'%C%y%m%d%H%M%S').$TOFILE
        cat < $PNAME > $Preport &
      else
        cat < $PNAME | lpr &
      fi
      return
    else
    if [ $DPARM = "-c" ]               # option -c (close)
    then
      if [ -a $PNAME ]
       then
         rm $PNAME
      fi

      if [[ -a $Preport ]]             #kluge 
      then
        RPTNAM=$( basename $2 | awk '{print substr($0,1,8)}' )

        if [ -s  `ls -rt1 ${PNAME%%.pip}* | tail -1` ]
        then
           cos $COSREPORT -c FSrptdist  -aCv $RPTNAM
           if [[ $?  != "0" ]]
           then
             echo in COSREPORT !!!
             echo
             echo The report will need to be printed manually...
             echo
           fi
         else
           echo "Report is empty will not distribute..."
        fi
      fi
      return
    fi
    fi
    fi
  fi

  echo "Usage: PrintPipe -[orc] <FIFO filename> <command> ..."
  exit -1

}

function PrintPipe
{
  printpipe $1 $2 $3

}
#-----------------------------------------------------------

