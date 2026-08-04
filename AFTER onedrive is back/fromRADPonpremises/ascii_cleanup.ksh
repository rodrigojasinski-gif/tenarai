#!/bin/ksh
echo "$Id: ascii_cleanup.ksh,v 1.5 2020/02/21 19:47:23 sg107540 Exp $"
#########################################################################################
#
#  ascii_cleanup.ksh
#
#  Remove ASCII control characters and convert unprintable characters to a carrot "^"
#  This includes the ASCII Extended Character set.
#
#########################################################################################

INPUT_FILE=$1
OUTPUT_FILE=$2
TEMP_FILE=$3

if [ $# -lt 3 ]
then
   echo "ascii_cleanup.ksh requires input parameters"
   echo "   1. INPUT_FILE"
   echo "   2. OUTPUT_FILE"
   echo "   3. TEMP_FILE"

echo $INPUT_FILE
echo $OUTPUT_FILE
echo $TEMP_FILE

   abndalrt.ksh ascii_cleanup.ksh.parms.are.missing
fi

echo "\n*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
echo "Starting ascii_cleanup.ksh\n"
###############################################################################
#
# Standard cleanup used before adding:
#     1) ppt077.ksh special character translation 240 --> 040
#     2) the extended ascii character set: -\377
#
#    cat $INPUT_FILE                       | \
#       tr -d '\032'                       | \
#       tr '\000-\011\013-\037\177' '[^*]' | \
#       sed 's/\^$//' > $OUTPUT_FILE
#
###############################################################################
#
# Line by line breakdown of what each statement does:
# 1. tr '(octal 032)' '(octal 040)' <--- PG: DOS EOF / SUBstitution character to space (Remove was causing problems for CA Volvo)
#                                   <--- prior logic removed DOS EOF / SUBstitution character 
#    tr -d '\032'        | \        <--- prior command line that was replaced
#
# 2. Catch and translate any special characters: 
#    tr '(octal 240)' '(octal 040)' <--- RS: Change invalid character (octal 240) to space (octal 040) - ppt077.ksh
#  
#    convert tab (octal 011) to pipe (octal 174 e.g. "|")  <--PG: Impacted Harley Davidson Motorcycle
#  
# 3. Retain (keep) the line feed (octal 012) and the standard visible keyboard characters (octal 040 - octal 176).
#    Change the rest to a carrot (^) leaving a 'clean' ASCII file.
#    
# 4. Finally the line (sed's/\^$//') removes empty lines from the file

cat ${INPUT_FILE}                            | \
     tr '\032' '\040'                        | \
     tr '\240' '\040'                        | \
     tr '\011' '\174'                        | \
     tr '\000-\011\013-\037\177-\377' '[^*]' | \
     sed 's/\^$//'                           | \
     awk 'length($0)>1' > ${OUTPUT_FILE}

####################################################################################################################
#  Verify translation:
#  When the -c and -d options of the tr command are used in combination like this, ONLY characters
#  specified on the command line are written.
#  Tell tr to retain only the octal characters 012, and 040 thru 176... 012 corresponds to the [LINEFEED] character.
####################################################################################################################

cat ${OUTPUT_FILE} | tr -cd '\012\040-\176' > ${TEMP_FILE}

WORKLINE=`wc ${INPUT_FILE}`
ROW_COUNT=`echo $WORKLINE | cut -f1 -d" "`
if [ "${ROW_COUNT}" = "0" ]
then
   echo "Zero rows to check"
else
   WORKLINE=`ls -l ${OUTPUT_FILE}`
   OUTPUT_FILESIZE=`echo ${WORKLINE} | cut -f5 -d" "`

   WORKLINE=`ls -l ${TEMP_FILE}`
   TEMP_FILESIZE=`echo ${WORKLINE} | cut -f5 -d" "`
   if [ ${OUTPUT_FILESIZE} = ${TEMP_FILESIZE} ]
   then
      echo "${OUTPUT_FILESIZE} = ${TEMP_FILESIZE}"
      echo "FILESIZE OK"
   else
      echo "\nFILESIZE ERROR!!!"
      echo "${OUTPUT_FILESIZE}"
      echo "${TEMP_FILESIZE}\n"
      $( abndalrt.ksh ascii.cleanup.ksh.translated.file.size.wrong )
   fi
fi

echo "\nExiting ascii_cleanup.ksh"
echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*\n"

###############################################################################
#  http://www.jimprice.com/jim-asc.htm
#  ASCII Chart
#  ASCII - The American Standard Code for Information Interchange
#  is a standard seven-bit code that was proposed by ANSI in 1963,
#  and finalized in 1968.
#  Other sources also credit much of the work on ASCII to work done
#  in 1965 by Robert W. Bemer (www.bobbemer.com).
#  ASCII was established to achieve compatibility between various types
#  of data processing equipment. Later-day standards that document ASCII
#  include ISO-14962-1997 and ANSI-X3.4-1986(R1997).
#
#  ASCII, pronounced "ask-key", is the common code for microcomputer equipment.
#
#  The standard ASCII character set consists of 128 decimal numbers
#  ranging from zero through 127 assigned to letters, numbers, punctuation marks,
#  and the most common special characters.
#
#  The Extended ASCII Character Set also consists of 128 decimal numbers
#  and ranges from 128 through 255 representing additional special, mathematical,
#  graphic, and foreign characters.
#
#
#  Converting Hex to Decimal
#  Here's a chart that shows the conversion between hex and decimal.
#
#      0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F.
#  0  000 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015
#  1  016 017 018 019 020 021 022 023 024 025 026 027 028 029 030 031
#  2  032 033 034 035 036 037 038 039 040 041 042 043 044 045 046 047
#  3  048 049 050 051 052 053 054 055 056 057 058 059 060 061 062 063
#  4  064 065 066 067 068 069 070 071 072 073 074 075 076 077 078 079
#  5  080 081 082 083 084 085 086 087 088 089 090 091 092 093 094 095
#  6  096 097 098 099 100 101 102 103 104 105 106 107 108 109 110 111
#  7  112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127
#  8  128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143
#  9  144 145 146 147 148 149 150 151 152 153 154 155 156 157 158 159
#  A  160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175
#  B  176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191
#  C  192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207
#  D  208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223
#  E  224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239
#  F  240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255
#
#  If you're having trouble getting the hang of the above chart, here's a hint.
#  Hex 41 (written as 0x41 in the programing language C) is equivalent to decimal 65.
#
#  Converting Hex to Octal
#  Here's a chart that shows the conversion between hex and octal.
#
#      0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F.
#  0  000 001 002 003 004 005 006 007 010 011 012 013 014 015 016 017
#  1  020 021 022 023 024 025 026 027 030 031 032 033 034 035 036 037
#  2  040 041 042 043 044 045 046 047 050 051 052 053 054 055 056 057
#  3  060 061 062 063 064 065 066 067 070 071 072 073 074 075 076 077
#  4  100 101 102 103 104 105 106 107 110 111 112 113 114 115 116 117
#  5  120 121 122 123 134 125 126 127 130 131 132 133 134 135 136 137
#  6  140 141 142 143 144 145 146 147 150 151 152 153 154 155 156 157
#  7  160 161 162 163 164 165 166 167 170 171 172 173 174 175 176 177
#  8  200 201 202 203 204 205 206 207 210 211 212 213 214 215 216 217
#  9  220 221 222 223 224 225 226 227 230 231 232 233 234 235 236 237
#  A  240 241 242 243 244 245 246 247 250 251 252 253 254 255 256 257
#  B  260 261 262 263 264 265 266 267 270 271 272 273 274 275 276 277
#  C  300 301 302 303 304 305 306 307 310 311 312 313 314 315 316 317
#  D  320 321 322 323 324 325 326 327 330 331 332 333 334 335 336 337
#  E  340 341 342 343 344 345 346 347 350 351 352 353 354 355 356 357
#  F  360 361 362 363 364 365 366 367 370 371 372 373 374 375 376 377
#
#
#  If you're having trouble getting the hang of the above chart, here's a hint.
#  Hex 41 (written as 0x41 in the programing language C) is equivalent to octal 101.
#
#
#
#
#
#  ASCII Chart
#  The following chart contains ASCII decimal, octal, hexadecimal and character codes.
#
#  Decimal Octal Hex  Character Description
#     0      0    00  NUL
#     1      1    01  SOH       start of header
#     2      2    02  STX       start of text
#     3      3    03  ETX       end of text
#     4      4    04  EOT       end of transmission
#     5      5    05  ENQ       enquiry
#     6      6    06  ACK       acknowledge
#     7      7    07  BEL       bell
#     8     10    08  BS        backspace
#     9     11    09  HT        horizontal tab
#    10     12    0A  LF        line feed
#    11     13    0B  VT        vertical tab
#    12     14    0C  FF        form feed
#    13     15    0D  CR        carriage return
#    14     16    0E  SO        shift out
#    15     17    0F  SI        shift in
#    16     20    10  DLE       data link escape
#    17     21    11  DC1       no assignment, but usually XON
#    18     22    12  DC2
#    19     23    13  DC3       no assignment, but usually XOFF
#    20     24    14  DC4
#    21     25    15  NAK       negative acknowledge
#    22     26    16  SYN       synchronous idle
#    23     27    17  ETB       end of transmission block
#    24     30    18  CAN       cancel
#    25     31    19  EM        end of medium
#    26     32    1A  SUB       substitute
#    27     33    1B  ESC       escape
#    28     34    1C  FS        file seperator
#    29     35    1D  GS        group seperator
#    30     36    1E  RS        record seperator
#    31     37    1F  US        unit seperator
#    32     40    20  SPC       space
#    33     41    21  !
#    34     42    22  "
#    35     43    23  #
#    36     44    24  $
#    37     45    25  %
#    38     46    26  &
#    39     47    27  '
#    40     50    28  (
#    41     51    29  )
#    42     52    2A  *
#    43     53    2B  +
#    44     54    2C  ,
#    45     55    2D  -
#    46     56    2E  .
#    47     57    2F  /
#    48     60    30  0
#    49     61    31  1
#    50     62    32  2
#    51     63    33  3
#    52     64    34  4
#    53     65    35  5
#    54     66    36  6
#    55     67    37  7
#    56     70    38  8
#    57     71    39  9
#    58     72    3A  :
#    59     73    3B  ;
#    60     74    3C  <
#    61     75    3D  =
#    62     76    3E  >
#    63     77    3F  ?
#    64    100    40  @
#    65    101    41  A
#    66    102    42  B
#    67    103    43  C
#    68    104    44  D
#    69    105    45  E
#    70    106    46  F
#    71    107    47  G
#    72    110    48  H
#    73    111    49  I
#    74    112    4A  J
#    75    113    4B  K
#    76    114    4C  L
#    77    115    4D  M
#    78    116    4E  N
#    79    117    4F  O
#    80    120    50  P
#    81    121    51  Q
#    82    122    52  R
#    83    123    53  S
#    84    124    54  T
#    85    125    55  U
#    86    126    56  V
#    87    127    57  W
#    88    130    58  X
#    89    131    59  Y
#    90    132    5A  Z
#    91    133    5B  [
#    92    134    5C  \
#    93    135    5D  ]
#    94    136    5E  ^
#    95    137    5F  _
#    96    140    60  `
#    97    141    61  a
#    98    142    62  b
#    99    143    63  c
#   100    144    64  d
#   101    145    65  e
#   102    146    66  f
#   103    147    67  g
#   104    150    68  h
#   105    151    69  i
#   106    152    6A  j
#   107    153    6B  k
#   108    154    6C  l
#   109    155    6D  m
#   110    156    6E  n
#   111    157    6F  o
#   112    160    70  p
#   113    161    71  q
#   114    162    72  r
#   115    163    73  s
#   116    164    74  t
#   117    165    75  u
#   118    166    76  v
#   119    167    77  w
#   120    170    78  x
#   121    171    79  y
#   122    172    7A  z
#   123    173    7B  {
#   124    174    7C  |
#   125    175    7D  }
#   126    176    7E  ~
#   127    177    7F  DEL delete
#   128    200    80  Reserved
#   129    201    81  Reserved a a
#   130    202    82  Reserved b b
#   131    203    83  Reserved c c
#   132    204    84  IND       Index (FE) d d
#   133    205    85  NEL       Next Line (FE) e e
#   134    206    86  SSA       Start of Selected Area f f
#   135    207    87  ESA       End of Selected Area g g
#   136    210    88  HTS       Horizontal Tabulation Set (FE) h h
#   137    211    89  HTJ       Horizontal Tabulation with Justification (FE) i i
#   138    212    8A  VTS       Vertical Tabulation Set (FE)
#   139    213    8B  PLD       Partial Line Down (FE)
#   140    214    8C  PLU       Partial Line Up (FE)
#   141    215    8D  RI        Reverse Index (FE)
#   142    216    8E  SS2       Single Shift Two (1)
#   143    217    8F  SS3       Single Shift Three (1)
#   144    220    90  DCS       Device Control String (2)
#   145    221    91  PU1       Private Use One j j
#   146    222    92  PU2       Private Use Two k k
#   147    223    93  STS       Set Transmit State l l
#   148    224    94  CCH       Cancel Character m m
#   149    225    95  MW        Message Waiting n n
#   150    226    96  SPA       Start of Protected Area o o
#   151    227    97  EPA       End of Protected Area p p
#   152    230    98  Reserved q q
#   153    231    99  Reserved r r
#   154    232    9A  Reserved
#   155    233    9B  CSI       Control Sequence Introducer (1)
#   156    234    9C  ST        String Terminator (2)
#   157    235    9D  OSC       Operating System Command (2)
#   158    236    9E  PM        Privacy Message (2)
#   159    237    9F  APC       Application Program Command (2)
#   160    240    A0
#   161    241    A1
#   162    242    A2     s s
#   163    243    A3     t t
#   164    244    A4     u u
#   165    245    A5     v v
#   166    246    A6     w w
#   167    247    A7     x x
#   168    250    A8     y y
#   169    251    A9     z z
#   170    252    AA
#   171    253    AB
#   172    254    AC
#   173    255    AD
#   174    256    AE
#   175    257    AF
#   176    260    B0
#   177    261    B1
#   178    262    B2
#   179    263    B3
#   180    264    B4
#   181    265    B5
#   182    266    B6
#   183    267    B7
#   184    270    B8
#   185    271    B9     `      Grave Accent
#   186    272    BA
#   187    273    BB
#   188    274    BC
#   189    275    BD
#   190    276    BE
#   191    277    BF
#   192    300    C0
#   193    301    C1     A A
#   194    302    C2     B B
#   195    303    C3     C C
#   196    304    C4     D D
#   197    305    C5     E E
#   198    306    C6     F F
#   199    307    C7     G G
#   200    310    C8     H H
#   201    311    C9     I I
#   202    312    CA
#   203    313    CB
#   204    314    CC
#   205    315    CD
#   206    316    CE
#   207    317    CF
#   208    320    D0
#   209    321    D1     J J
#   210    322    D2     K K
#   211    323    D3     L L
#   212    324    D4     M M
#   213    325    D5     N N
#   214    326    D6     O O
#   215    327    D7     P P
#   216    330    D8     Q Q
#   217    331    D9     R R
#   218    332    DA
#   219    333    DB
#   220    334    DC
#   221    335    DD
#   222    336    DE
#   223    337    DF
#   224    340    E0
#   225    341    E1
#   226    342    E2     S S
#   227    343    E3     T T
#   228    344    E4     U U
#   229    345    E5     V V
#   230    346    E6     W W
#   231    347    E7     X X
#   232    350    E8     Y Y
#   233    351    E9     Z Z
#   234    352    EA
#   235    353    EB
#   236    354    EC
#   237    355    ED
#   238    356    EE
#   239    357    EF
#   240    360    F0     0 0
#   241    361    F1     1 1
#   242    362    F2     2 2
#   243    363    F3     3 3
#   244    364    F4     4 4
#   245    365    F5     5 5
#   246    366    F6     6 6
#   247    367    F7     7 7
#   248    370    F8     8 8
#   249    371    F9     9 9
#   250    372    FA
#   251    373    FB
#   252    374    FC
#   253    375    FD
#   254    376    FE
#   255    377    FF
###############################################################################

###############################################################################
#  END ascii_cleanup.ksh
###############################################################################
