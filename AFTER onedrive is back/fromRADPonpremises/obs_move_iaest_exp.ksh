#!/bin/ksh -x

SAVELIST="put.exp mput.exp get.exp mget.exp"
A8400="/prod/util/share/bin"
B8400=$A8400
X8400="/mdev/util/share/bin"

for FILE in $SAVELIST;do
cp -p $A8400/iaest_$FILE $A8400/iaest_orig_$FILE
mv $A8400/iaest_t$FILE $A8400/iaest_$FILE
rcp -p $A8400/iaest_$FILE b8400:$B8400/iaest_$FILE
rcp -p $A8400/iaest_$FILE x8400:$X8400/iaest_$FILE
done
