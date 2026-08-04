#############################################################################
# This make file is used to test checkin/checkout/prodmove.
# It is also used to compile test program ttt_um_ftp_put.
#
# 12    <== change this in order for checkin to detect a change.
#$Id: ttt_um_ftp_put.mk,v 1.6 2021/07/03 01:49:17 pg2697 Exp $
#############################################################################

.COMPILEIT: build
build:
	gcc -maix64 -w -nostdinc -I /usr/include -c ttt_um_ftp_put.c

	make -f /vend/oracle/11.2.0.4/rdbms/demo/demo_rdbms.mk extproc_nocallback SHARED_LIBNAME=ttt_um_ftp_put.so OBJS=ttt_um_ftp_put.o

## END
