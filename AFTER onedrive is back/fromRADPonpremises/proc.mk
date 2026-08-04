#############################################################################
# This make file is used to compile Pro c Oracle programs like mfconnect.pc
# The macro definition fills in some details or overrides some defaults from
# other files.
#
# GW 8/21/12 - Modifications for IBM AIX 770 and Oracle 11g
# PG 2/16/21 - AIX 7.1 to 7.2 Migration
#############################################################################
##include $(ORACLE_HOME)/precomp/lib/env_precomp.mk
include /$(ACT_LVL)/race/share/bin/env_precomp.mk

CLEAN1	= -@rm -f $@.c $@.o

.SUFFIXES: .pc .c

# proc and c
.pc:
	$(CLEAN1)
	$(PROC) $(PROCPLSFLAGS) iname=$*.pc
 	                                                                         ## ibm770 AIX & Oracle 11g modification 8/21/12
	                                                                         ##$(CC) $(CFLAGS) -c $*.c
	$(CC) -c $*.c

##########
OTTFLAGS=$(PCCFLAGS)
CLIBS= $(TTLIBS_QA) $(LDLIBS)
PRODUCT_LIBHOME=
MAKEFILE=$(ORACLE_HOME)/precomp/demo/proc/demo_proc.mk
PROCPLSFLAGS= sqlcheck=SEMANTICS userid=$(USERID)
PROCPPFLAGS= code=cpp $(CCPSYSINCLUDE)
NETWORKHOME=$(ORACLE_HOME)/network/
PLSQLHOME=$(ORACLE_HOME)/plsql/
INCLUDE=$(I_SYM). $(I_SYM)$(PRECOMPHOME)public $(I_SYM)$(RDBMSHOME)public $(I_SYM)$(RDBMSHOME)demo $(I_SYM)$(PLSQLHOME)public $(I_SYM)$(NETWORKHOME)public
I_SYM=-I
STATICCPPLDLIBS=$(SCOREPT) $(SSCOREED) $(DEF_ON) $(LLIBCLIENT) $(LLIBSQL) $(STATICTTLIBS)
CPPLDLIBS=$(LLIBCLNTSH)
PROC=$(ORACLE_HOME)/bin/proc
                                                                            ##GW 8/21/12 - ibm770 AIX & Oracle 11g modification 
                                                                            ##CC=/usr/bin/gcc
                                                                            ##PG 02/16/21 - AIX 7.1 to 7.2 Migration 
                                                                            ##CC=/usr/bin/gcc -maix64 -nostdinc -I /usr/include
CC=gcc -maix64 -w -nostdinc -I /usr/include
USERID=scott/wgec1Lna7qerh0
