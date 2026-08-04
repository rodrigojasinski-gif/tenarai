#! /bin/ksh  
#$Id: compile.ksh,v 1.3 2007/04/09 18:37:26 gw8440 Exp $
##set -xv
##############################################################################
# compile.ksh                                                     *08/07/97* #
#                                                                            #
#   This script will compile and link MF Cobol programs.                     #
#                                                                            #
#   COMMAND LINE:                                                            #
#                                                                            #
#     filename( without .cbl extention )                                     #
#                                                                            #
#   ENVIRONMENT:                                                             #
#                                                                            #
#     ORACLE_HOME  - Oracle path                                             #
#     COBDIR       - Micro Focus Cobol path                                  #
#     MSYS         - Mitchell System path                                    #
#                                                                            #
#   NOTE:                                                                    #
#                                                                            #
#    8/20/01 - Modified for RACE by jhh                                      #
#    4/3/07  - Modified for IBM AIX                                          #    
#                                                                            #
##############################################################################

  trap 'exit -1' err

  export MSYS=$RACE
  export LIBPATH=$LIBPATH::$MSYS/../share/lib:$COBDIR/coblib


###
#
# Validate command line/parameters
#
###
  if [ $# = "0" ]                                 # check for parameter
  then
    echo "usage: compile.ksh filename" "\007" >&2
    exit -2
  fi

  if ! [ -a $1.cbl ]                              # check for file
  then
    echo "\007File not found -" $1.cbl >&2
    exit -2
  fi

  if ! [ $(printenv ORACLE_HOME) ]
  then
    echo "environment variable ORACLE_HOME required"
    exit -1
  fi

  if ! [ $(printenv LIBPATH) ]
  then
    echo "environment variable LIBPATH required"
    exit -1
  fi

  if ! [ $(printenv COBDIR) ]
  then
    echo "environment variable COBDIR required"
    exit -1
  fi

  if ! [ $(printenv MSYS) ]
  then
    echo "environment variable MSYS required"
    exit -1
  fi

  export COBCPY=$COBCPY:$MSYS/inc:$RACE/../share/inc:

echo "Compile environment:"
echo "LIBPATH: $LIBPATH"
echo "COBCPY: $COBCPY"
echo 

###
#
# Set MF Cobol object dependencies
#
###
                                                  # scan for subroutines
  OBJS=$(awk 'substr($0,7,1) != "*"' $1.cbl | \
         awk '$1 == "CALL" {print tolower($2)"\n"}' | \
         sed '1,$s/\.//g' | \
         sed '1,$s/"//g')
                                                  # scan for sub-subroutines
  OBJS1=$(for I in $OBJS;
          do if [ -a $MSYS/src/$I.cbl ]
             then
               awk 'substr($0,7,1) != "*"' $MSYS/src/$I.cbl | \
               awk '$1 == "CALL" {print tolower($2)"\n"}'
             else
               if [ -a $MSYS/../share/src/$I.cbl ]
               then
                 awk 'substr($0,7,1) != "*"' $MSYS/../share/src/$I.cbl | \
                 awk '$1 == "CALL" {print tolower($2)"\n"}'
               fi
             fi;
          done             | \
          sed '1,$s/\.//g' | \
          sed '1,$s/"//g'
         )

  OBJS1=$OBJS" "$OBJS1                            # combine results

  OBJS1=$( for I in $OBJS1;
            do printf "%s\n" $I
           done  | \
           sort -u
        )                                         # drop duplicates

  OBJS=$(for I in $OBJS1;
           do printf "%s\n" $I | \
              if [[ -a ./$I.o ]]
              then
                awk -v CURRENT_DIR="./" '{printf(CURRENT_DIR"%s.o ",$0)}'
              else
                if [[ -a $MSYS/lib/$I.o ]]
                then
                  awk -v MSYS=$MSYS '{printf(MSYS"/lib/%s.o ",$0)}'
                else
                  if [[ -a $MSYS/../share/lib/$I.o ]]
                  then
                    awk -v MSYS=$MSYS '{printf(MSYS"/../share/lib/%s.o ",$0)}'
                  else
                    awk -v STGDIR=$STGDIR '{printf(STGDIR"/../share/lib/%s.o ",$0)}'
                  fi
                fi
              fi
           done )

  export OBJS

###
#
# Compile
#
###
  rm -f $1                                        # remove previous executable

  if [ $(grep -ci " SQL" $1.cbl) -gt 0 ]          # check for SQL code
  then
    export CFLG2=$2
    make -f /$ACT_LVL/race/share/bin/procob.mk $1    #make Oracle/Cobol program
  else
    make -f /$ACT_LVL/race/share/bin/coblnk.mk $1   #make Cobol program
  fi
