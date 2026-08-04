##############################################################################
# coblnk cobol_pgm                                                           #
#                                                                            #
#    Modified for RACE by jhh - 8/20/01                                      #
#                                                                            #
##############################################################################

C	= c
CBL	= cbl
CLEAN1	= -@rm $@.int
CLEAN2	= -@rm $@.o
OBJ	= o
OPT1	= -C "IBMCOMP DEFAULTCALLS=4 FOLDCOPYNAME=LOWER FOLDCALLNAME=LOWER LIST() SETTING"
SRC	= .

.SUFFIXES: .cbl

subr iisr906 mexr001 mptr998 \
mexr002 \
xcgr001 xcgr005 xcgr006 \
xcgr007 xcgr008 xcgr010 \
xcgr011 xcgr012 xcgr015 xcgr016 xcgr022:
	@cob $(OPT1) -W e -c -x $(SRC)/$@.$(CBL)
	$(CLEAN1)

.cbl:
	@cob $(OPT1) -W e -x  $(SRC)/$*.$(CBL) $(OBJS) 
	$(CLEAN1)
	$(CLEAN2)
