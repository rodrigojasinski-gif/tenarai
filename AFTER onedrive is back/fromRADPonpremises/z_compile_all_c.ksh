##############################################################################
# compile_all_c.ksh                                                          #
#                                                                            #
#   Subscript called by compile_all_c_pgms.ksh                               #
#   Used for Migration - mass compiling.                                     #
#                                                                            #
#   Each step does:                                                          #
#      - remove any source, object, and/or list files assoc'd with the pgm(s)# 
#      - checkout program(s) without lock                                    #
#      - compile called program(s), if any                                   #
#      - compile main program including called program object(s)             #
#      - list all files that were created as a result of the compile(s)      #
#                                                                            #
#  If you only need to compile one program, clone this script and adjust     #
#  where necessary.                                                          #
##############################################################################

trap 'exit -1' err >> $LOGFILE

export GCC_COMMAND="/usr/bin/gcc -maix64 -nostdinc -I /usr/include"

if [ $ACT_LVL = "prod" -o $ACT_LVL = "mdev" ]
then
   if [ $ACT_LVL = "prod" ]
   then
      VSID=radp
      umask 002         # set permissions
   else
      VSID=radd
   fi
else
   echo "\n ERROR: environment variable ACT_LVL must be prod or mdev"
   echo "\n ACT_LVL is set to --> $ACT_LVL"
   echo "\n Check script /etc/profile and verify value."
   return -1
fi

echo "\n ACTIVITY LEVEL is $ACT_LVL"
echo "\n ACTIVITY LEVEL is $ACT_LVL" >> $LOGFILE


##############################################################################
# program: ascii2e (and associated programs)
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to ascii2e 

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to ascii2e" >> $LOGFILE
  rm -f atoe* >> $LOGFILE
  rm -f ascii2e* >> $LOGFILE

  echo "\n-- Check out files associated to ascii2e" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out atoe.c share/src   >> $LOGFILE
    rcheck_out ascii2e.c share/bin >> $LOGFILE
  else
    co -u -f /prod/race/share/src/RCS/atoe.c,v >> $LOGFILE
    co -u -f /prod/race/share/bin/RCS/ascii2e.c,v >> $LOGFILE
  fi

  echo "\n-- Compile atoe.c as a .o object to be called by ascii2e" >> $LOGFILE
  ${GCC_COMMAND} -c atoe.c 2>&1 >> $LOGFILE

  echo "\n-- Compile ascii2e.c with linked subroutine atoe.o" >> $LOGFILE
  ${GCC_COMMAND} -o ascii2e ascii2e.c atoe.o 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to ascii2e" >> $LOGFILE  
  mv /$ACT_LVL/race/share/lib/atoe.o /$ACT_LVL/race/share/lib/rollback/atoe.o
  mv /$ACT_LVL/race/share/bin/ascii2e /$ACT_LVL/race/share/bin/rollback/ascii2e
  mv atoe.o /$ACT_LVL/race/share/lib
  mv ascii2e /$ACT_LVL/race/share/bin

  echo "\n-- List files associated to ascii2e" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/lib/atoe* >> $LOGFILE
  ls -l /$ACT_LVL/race/share/bin/ascii2e* >> $LOGFILE


##############################################################################
# program: ebcdic2a  (and associated programs)
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to ebcdic2a 

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to ebcdic2a" >> $LOGFILE
  rm -f etoa* >> $LOGFILE
  rm -f ebcdic2a* >> $LOGFILE

  echo "\n-- Check out files associated to ebcdic2a" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out etoa.c share/src   >> $LOGFILE
    rcheck_out ebcdic2a.c share/bin >> $LOGFILE
  else
    co -u -f /prod/race/share/src/RCS/etoa.c,v >> $LOGFILE
    co -u -f /prod/race/share/bin/RCS/ebcdic2a.c,v >> $LOGFILE
  fi

  echo "\n-- Compile etoa.c as a .o object to be called by ebcdic2a" >> $LOGFILE
  ${GCC_COMMAND} -c etoa.c 2>&1 >> $LOGFILE

  echo "\n-- Compile ebcdic2a.c with linked subroutine etoa.o" >> $LOGFILE
  ${GCC_COMMAND} -o ebcdic2a ebcdic2a.c etoa.o 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to ebcdic2a" >> $LOGFILE 
  mv /$ACT_LVL/race/share/lib/etoa.o /$ACT_LVL/race/share/lib/rollback/etoa.o
  mv /$ACT_LVL/race/share/bin/ebcdic2a /$ACT_LVL/race/share/bin/rollback/ebcdic2a 
  mv etoa.o /$ACT_LVL/race/share/lib
  mv ebcdic2a /$ACT_LVL/race/share/bin

  echo "\n-- List files associated to ascii2e" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/lib/etoa* >> $LOGFILE
  ls -l /$ACT_LVL/race/share/bin/ebcdic2a*  >> $LOGFILE


##############################################################################
# program: dataclean
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to dataclean 

  echo "\n-----------------------------------------" >> $LOGFILE 
  echo "\n-- Remove files associated to dataclean" >> $LOGFILE
  rm -f dataclean* >> $LOGFILE

  echo "\n-- Check out files associated to dataclean" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out dataclean.c share/bin >> $LOGFILE
  else
    co -u -f /prod/race/share/bin/RCS/dataclean.c,v >> $LOGFILE
  fi

  echo "\n-- Compile dataclean.c - no linked routines" >> $LOGFILE
  ${GCC_COMMAND} -o dataclean dataclean.c 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to dataclean" >> $LOGFILE  
  mv /$ACT_LVL/race/share/bin/dataclean /$ACT_LVL/race/share/bin/rollback/dataclean
  mv dataclean /$ACT_LVL/race/share/bin

  echo "\n-- List files associated to dataclean" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/bin/dataclean*  >> $LOGFILE


##############################################################################
# program: fixlen
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to fixlen 

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to fixlen" >> $LOGFILE
  rm -f fixlen* >> $LOGFILE

  echo "\n-- Check out files associated to fixlen" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out fixlen.c share/bin >> $LOGFILE
  else
    co -u -f /prod/race/share/bin/RCS/fixlen.c,v >> $LOGFILE
  fi  

  echo "\n-- Compile fixlen.c - no linked routines" >> $LOGFILE
  ${GCC_COMMAND} -o fixlen fixlen.c 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to fixlen" >> $LOGFILE  
  mv /$ACT_LVL/race/share/bin/fixlen /$ACT_LVL/race/share/bin/rollback/fixlen
  mv fixlen /$ACT_LVL/race/share/bin

  echo "\n-- List files associated to fixlen" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/bin/fixlen*  >> $LOGFILE


##############################################################################
# program: cobabend       (called by COBOL programs)
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to cobabend

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to cobabend" >> $LOGFILE
  rm -f cobabend* >> $LOGFILE

  echo "\n-- Check out files associated to cobabend" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out cobabend.c share/src   >> $LOGFILE
  else
    co -u -f /prod/race/share/src/RCS/cobabend.c,v >> $LOGFILE
  fi
  
  echo "\n-- Compile cobabend.c as a .o object to be called by COBOL programs" >> $LOGFILE
  ${GCC_COMMAND} -c cobabend.c 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to cobabend" >> $LOGFILE  
  mv /$ACT_LVL/race/share/lib/cobabend.o /$ACT_LVL/race/share/lib/rollback/cobabend.o
  mv cobabend.o /$ACT_LVL/race/share/lib

  echo "\n-- List files associated to cobabend" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/lib/cobabend*  >> $LOGFILE


##############################################################################
# program: dberrmsg   Pro-C program called by COBOL pgms; interacts w/ Oracle)
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to dberrmsg

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to dberrmsg" >> $LOGFILE
  rm -f dberrmsg* >> $LOGFILE

  echo "\n-- Check out files associated to dberrmsg" >> $LOGFILE 
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out dberrmsg.pc share/src   >> $LOGFILE
  else
    co -u -f /prod/race/share/src/RCS/dberrmsg.pc,v >> $LOGFILE
  fi

  echo "\n-- Exec proccomp script to: Compile dberrmsg.c as a .o object to be called by COBOL programs" >> $LOGFILE
  proccomp dberrmsg 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to dberrmsg" >> $LOGFILE  
  mv /$ACT_LVL/race/share/lib/dberrmsg.o /$ACT_LVL/race/share/lib/rollback/dberrmsg.o
  mv dberrmsg.o /$ACT_LVL/race/share/lib

  echo "\n-- List files associated to dberrmsg" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/lib/dberrmsg*  >> $LOGFILE


##############################################################################
# program: mfconnect  Pro-C program called by COBOL pgms; interacts w/ Oracle)
##############################################################################
  echo ----------------------------------------- 
  echo -- Running steps associated to mfconnect

  echo "\n-----------------------------------------" >> $LOGFILE
  echo "\n-- Remove files associated to mfconnect" >> $LOGFILE
  rm -f mfconnect* >> $LOGFILE

  echo "\n-- Check out files associated to mfconnect" >> $LOGFILE
  if [ $ACT_LVL = "mdev" ]
  then 
    rcheck_out mfconnect.pc share/src   >> $LOGFILE
  else
    co -u -f /prod/race/share/src/RCS/mfconnect.pc,v >> $LOGFILE
  fi
 
  echo "\n-- Exec proccomp script to: Compile mfconnect.c as a .o object to be called by COBOL programs" >> $LOGFILE
  proccomp mfconnect 2>&1 >> $LOGFILE

  echo "\n-- Move executables associated to mfconnect" >> $LOGFILE  
  mv /$ACT_LVL/race/share/lib/mfconnect.o /$ACT_LVL/race/share/lib/rollback/mfconnect.o
  mv mfconnect.o /$ACT_LVL/race/share/lib

  echo "\n-- List files associated to mfconnect" >> $LOGFILE 
  ls -l /$ACT_LVL/race/share/lib/mfconnect*  >> $LOGFILE

##############################################################################
# All C-related stuff is compiled and moved to execution directories. 
# Now instruct user to execute move request.
# MDEV - Executables have been moved to one of the following:
#        /mdev/race/share/bin
#        /mdev/race/share/inc 
# PROD - Executables have been moved to one of the following:
#        /prod/race/share/bin
#        /prod/race/share/inc    
# Compile listings are not moved or removed so that developer/RACEDataOps can 
#        review them.
##############################################################################
