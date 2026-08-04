#!/bin/ksh

# @(#) datecalc - date math, using only the KornShell and 'date'
# IDD and ODD are input & output date field delimiters. respectively
# Note: if a '-' is included in "IDD", make it 1st or last

IDD="/.-"  # acceptable:  Input  Date [Field] Delimiter(s)
ODD="/"    # default:     Output Date [Field] Delimiter

ARGS="$@" ARG1=$1 ARG2=$2 NUM_ARGS=$#
trap '
  trap EXIT
  [[ -n $ERR ]] && {
    : ${cl:=$(tput clear)} ${se:=$(tput rmso)} ${so:=$(tput smso)}
    PROG=${0##*/} ; [[ -n $se && -n $se ]] && PROG="$so $PROG $se"

    usage="Use $PROG to return the:\n
  Date n days before (-n) or after (+n) today:\n
    $PROG -n | [+]n\n
  Date n days before (-n) or after (+n) a given date:\n
    $PROG -n|[+]n [m]m/[d]d/[yy]yy | [m]m/[d]d/[yy]yy -n|[+]n\n
  Number of days from today ( + or - ) to some other date:\n
    $PROG [m]m/[d]d/[yy]yy\n
  Number of days by which date1 precedes or follows (-) date2:\n
    $PROG [m]m/[d]d/[yy]yy [m]m/[d]d/[yy]yy\n
  ( A 2-digit year input date defaults to 19yy. )\n"

    case $ERR in
      1) ERR="Bad input data or format:" EX=1 ;;
      2) ERR="Bad month:" EX=2 ;; 3) ERR="Bad date:"      EX=3 ;;
      4) ERR="Bad year:"  EX=4 ;; 5) ERR="Before year 1:" EX=5 ;;
      6) ERR="Impossible date:" EX=6 ;;
    esac
    print -u2 "$cl$PROG: $ERR  $ARGS\n\n$usage" ; exit $EX ;}
  exit 0 ' EXIT HUP INT QUIT TERM

(( $# == 0 )) && { ERR=' ' ; exit ;}
(( $# >  2 )) && { ERR="Wrong argument count: $#  => " ; exit ;}
integer Mdays[13] mdays Ydays J M D Y NOW THEN N NUM1 NUM2
set -A Mdays 0 31 28 31 30 31 30 31 31 30 31 30 31
eval $( /bin/date '+J=%j M=%m D=%d Y=%Y NOW=%Y%m%d' )

# define functions:
# adjust for leap years:
function Leap { integer YR=$1
  (( YR % 4 == 0 && ( YR % 100 > 0 || YR % 400 == 0 || YR < 1800 ) )) &&
    Ydays=366 Mdays[2]=29 || Ydays=365 Mdays[2]=28
  (( YR == 1752 )) && Ydays=355 Mdays[9]=19 || Mdays[9]=30 ;}
# count to previous years, months and days:
function Prev_Y { (( N -= Ydays )) ; (( Y -= 1 )) ; unset mdays ; M=12 D=31 ;}
function Prev_M { (( N -= ${mdays:-${Mdays[M]}} )) ; (( M -= 1 ))
  unset mdays ; D=${Mdays[M]} ;}
function Prev_D { (( N -= 1 )) ; (( D -= 1 ))
  (( Y == 1752 && M == 9 && D == 13 )) && D=2 ;}
# count to next years, months and days:
function Next_Y { (( N -= Ydays )) ; (( Y += 1 )) ; unset mdays ; M=1  D=1  ;}
function Next_M { (( N -= ${mdays:-${Mdays[M]}} )) ; (( M += 1 ))
  unset mdays ; D=1 ;}
function Next_D { (( N -= 1 )) ; (( D += 1 ))
  (( D > Mdays[M] )) && D=1 M=$(( M += 1 ))
  (( Y == 1752 && M == 9 && D ==  2 )) && D=13 ;}

# get the number of days from a date to a date:
function GET_NUM { N=0
  case $1 in
    [01][0-9][$IDD][0-3][0-9][$IDD][0-9][0-9][0-9][0-9]) ;;
        [1-9][$IDD][0-3][0-9][$IDD][0-9][0-9][0-9][0-9]) ;;
         [01][0-9][$IDD][1-9][$IDD][0-9][0-9][0-9][0-9]) ;;
             [1-9][$IDD][1-9][$IDD][0-9][0-9][0-9][0-9]) ;;
              [01][0-9][$IDD][0-3][0-9][$IDD][0-9][0-9]) ;;
                  [1-9][$IDD][0-3][0-9][$IDD][0-9][0-9]) ;;
                   [01][0-9][$IDD][1-9][$IDD][0-9][0-9]) ;;
                       [1-9][$IDD][1-9][$IDD][0-9][0-9]) ;;
    *) return 1 ;;
  esac
  ifs=$IFS ; IFS="$IDD" ; set $1 ; IFS=$ifs
  integer M2=$1 D2=$2 Y2
  # 2-digit years default to 19yy:
  case ${#3} in 2) Y2=19$3 ;; 4) Y2=$3 ;; *) return 4 ;; esac
  (( Y2 == 0 )) && return 4
  Leap $Y2
  (( M2 < 1 || M2 > 12 )) && return 2
  (( D2 < 1 || ( D2 > ${Mdays[M2]} && Y2 != 1752 ) )) && return 3
  typeset -2Z m=$M2 d=$D2 ; typeset -4Z y=$Y2 ; THEN=$y$m$d
  case $THEN in 1752090[3-9]|1752091[0-3]|1752093[1-9]) return 6 ;; esac
  Leap $Y
  (( THEN > NOW )) && {
    Ydays=$(( Ydays - J + 1 )) ; mdays=$(( Mdays[M] - D + 1 ))
    CNT_Y=Next_Y CNT_M=Next_M CNT_D=Next_D ;} || { Ydays=$J ; mdays=$D
    CNT_Y=Prev_Y CNT_M=Prev_M CNT_D=Prev_D ;}
  while (( Y != Y2 )) ; do $CNT_Y ; Leap $Y ; done
  while (( M != M2 )) ; do $CNT_M ; done
  (( Y == 1752 && M == 9 && D == 19 )) && { [[ $CNT_D = Prev_D ]] && D=30 ;}
  while (( D != D2 )) ; do $CNT_D ; done
  (( THEN > NOW )) && (( N *= -1 ))
  print - $N ;}

# get the date a number of days before or after a date:
function GET_DATE { N=$1
  typeset -RZ2 Month Date ; typeset -RZ4 Year
  (( N == 0 )) || { Leap $Y
    (( N > 0 )) && { Ydays=$(( Ydays - J + 1 ))
      mdays=$(( Mdays[M] - $D + 1 ))
      CNT_Y=Next_Y CNT_M=Next_M CNT_D=Next_D ;} || { Ydays=$J ; mdays=$D
      CNT_Y=Prev_Y CNT_M=Prev_M CNT_D=Prev_D N=$(( N * -1 )) ;}
  while (( N >= Ydays )) ; do $CNT_Y ; Leap $Y ; done
  while (( N >= ${mdays:-${Mdays[M]}} )) ; do $CNT_M ; done
  (( Y == 1752 && M == 9 && D == 19 )) && { [[ $CNT_D = Prev_D ]] && D=30 ;}
  while (( N > 0 )) ; do $CNT_D ; done ;}
  (( Y > 0 )) || return 5
  Month=$M Date=$D Year=$Y
  print $Month$ODD$Date: 2007/12/26 23:22:10 $ODD$Year ;}

# the program itself:
(( $NUM_ARGS == 1 )) && {
  # one argument, which might be either an integer or a date
  [[ $ARG1 = ?([+-])+([0-9]) ]] && funct=GET_DATE || funct=GET_NUM
    ANSWER=$( $funct $ARG1 ) || { ERR=$? ; exit ;}
    print - $ANSWER && exit 0 ;}

[[ $ARG1 = ?([+-])+([0-9]) || $ARG2 = ?([+-])+([0-9]) ]] && {
  # two arguments, one of which is an integer
  [[ $ARG1 = ?([+-])+([0-9]) ]] && NUM1=$ARG1 DATE=$ARG2 || NUM1=$ARG2 DATE=$ARG1
  case $ARGS in */*) ODD=/ ;; *.*) ODD=. ;; *-*) ODD=- ;; esac
  NUM2=$( GET_NUM $DATE ) || { ERR=$? ; exit ;}
  DATE=$( GET_DATE $(( NUM2 + NUM1 )) ) || { ERR=$? ; exit ;}
  print - $DATE && exit 0 ;}

# two arguments, both of which are dates
NUM1=$( GET_NUM $ARG1 ) || { ERR=$? ; exit ;}
NUM2=$( GET_NUM $ARG2 ) || { ERR=$? ; exit ;}
print - $(( NUM2 - NUM1 )) && exit 0

exit 0

# EOF - 'datecalc'

=================================
Convert dd/mm/yyyy to mm/dd/yyyy:
=================================

  TEST="?([0-9])+([0-9][./-])?([0-9])+([0-9][./-][0-9][0-9])?([0-9][0-9])"
  for arg in $@
  do eval [[ $arg = $TEST ]] && {
     case $arg in *.*) sep=. ;; */*) sep=/ ;; *-*) sep=- ;; esac
     y=${arg##*[./-]} ; dm=${arg%[./-]*} ; d=${dm%[./-]*} ; m=${dm#*[./-]}
     ARG="$ARG $m$sep$d$sep$y" ;} || ARG="$ARG $arg"
  done
  set -- $ARG

=========================================================================
