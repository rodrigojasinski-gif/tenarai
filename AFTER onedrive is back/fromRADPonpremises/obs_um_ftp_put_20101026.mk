all: build run
build:
	gcc -c -maix64 um_ftp_put.c
	make -f /vend/oracle/10.2.0/rdbms/demo/demo_rdbms.mk extproc_nocallback \
	SHARED_LIBNAME=um_ftp_put.so OBJS=um_ftp_put.o
run:
	sqlplus ext/f00tba11 @um_ftp_put.sql
clean:	
	rm um_ftp_put.so
	rm um_ftp_put.o
