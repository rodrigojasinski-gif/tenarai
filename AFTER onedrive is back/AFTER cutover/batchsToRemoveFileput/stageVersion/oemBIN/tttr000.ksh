#!/bin/ksh
echo "RCS $Id: tttr000.ksh,v 1.4 2014/09/06 00:20:15 pg2697 Exp $"
########################################################################
# script to test checkout/checkin/prodmove
# 12 <== must change to allow checkin               
########################################################################

set -v
trap 'abndalrt.ksh $?' err
echo "\nTest1 - Line 1."
echo "\nTest1 - Line 2."
echo "\n"

echo "\nTest 2 - Line 1. \nTest 2 - Line 2."
echo "\n"

echo "\nTest3 - Line 1." > errmsg.txt
echo "\nTest3 - Line 2." >> errmsg.txt
cat errmsg.txt
rm -f errmsg.txt







 


