#!/bin/ksh
echo $Id: fileexist.ksh,v 1.2 2021/07/03 01:23:23 pg2697 Exp $
#================================================================#
# FileExist                                                      #
#                                                                #
#   DESCRIPTION                                                  #
#     This script will check the existance of a file on a remote #
#     host, if the file is  found it will scp a file to local    #
#     host which issued the rsh command.                         #
#     This script is used in the tape read jobs for OEM tapes    #
#     reformat.                                                  #
#                                                                #
#   EXAMPLE                                                      #
#     ssh -n rmthost path/FileExist rmtfile lochost locfile      #                   
#                                    $1      $2       $3         #
#   2021/06/25 PAG - Changed rcp to scp
#================================================================#
set -vx   
trap 'exit 4' err    
# $1 = remote file 
    if [[ -z $1 ]]
    then
      echo "\n               ==> No Remote File Specified <== \n" >&2
      exit 4
    fi

# $2 = local host  
    if [[ -z $2 ]]
    then
      echo "\n               ==> No Local Host Specified <== \n" >&2
      exit 4
    fi

# $3 = local file   
    if [[ -z $3 ]]
    then
      echo "\n               ==> No Local File Specified <== \n" >&2
      exit 4
    fi

if [ -e "$1" ]
then
  echo "$1 File Exists" > file.tmp
  scp file.tmp $2:$3
  rm -f file.tmp
fi
#========================================================#
# FileExist   END                                        #
#========================================================#
