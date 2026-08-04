## $Id: um_ftp_put.mk,v 1.5 2021/07/03 01:50:05 pg2697 Exp $ 
## 2021.02.19 PAG Changed /usr/bin/gcc to gcc (i.e. Removed path)

.COMPILEIT: build

build:
	gcc -maix64 -w -nostdinc -I /usr/include -c um_ftp_put.c

	make -f /vend/oracle/11.2.0.4/rdbms/demo/demo_rdbms.mk extproc_nocallback SHARED_LIBNAME=um_ftp_put.so OBJS=um_ftp_put.o

## END
