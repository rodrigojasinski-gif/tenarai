#!/bin/ksh
 echo "$Id: xam001.ksh,v 1.5 2016/04/27 20:04:56 pg2697 Exp $"
############################################################################
#  SUB-SCRIPT:  xam001                                                     #
############################################################################

set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh   $?' err    

#STEP Step010R                                                              
    export STEPNAME=Step010R
    echo "    Start   ${STEPNAME}           "$(date)
#*--------------------------------------------------------------------------
#  TRANSFER PARM FILE FROM NT TO UNIX. 
#  THEN CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER.    
#*--------------------------------------------------------------------------

     export DD_NOVELDSK=del_supplier_list.txt
     export DD_UNXDISK=$( setgdg.ksh "$RACE/dat/${JOBNAME}_del_supplier_list.xfr(+1)" NEW 15)
     export DD_NOVELDIR=${NOVELL}altp
     export DD_STDOUT=$RACE/tmp/${JOBNAME}_ftpstats.tmp

     fileget.exp $DD_NOVELDSK $DD_UNXDISK $DD_NOVELDIR \
     | tee   $DD_STDOUT

   novelcount=$( grep 'Information ret' $DD_STDOUT | awk '{print $1}') 
   unixcount=$(wc -c $DD_UNXDISK | awk '{print $1}') 

#* check for empty file and abend, if so
   if [ novelcount -eq unixcount ]
       then
          echo " ftp directory counts are good "
       else
          echo " ***** error ***** ftp directory counts do not match "
          echo " UNIX byte count = $unixcount "
          abndalrt.ksh ftp_get
   fi


#STEP Step020R 
    export STEPNAME=Step020R
    echo "    Start   ${STEPNAME}           "$(date)
#*--------------------------------------------------------------------------
#*  REMOVE CARRIAGE CONTROL FROM TRANSFERRED PARM FILE       
#*--------------------------------------------------------------------------                                                     
    export DD_SYSIN=$( setgdg.ksh "$RACE/dat/${JOBNAME}_del_supplier_list.xfr(0)")
    export DD_SYSOUT=$RACE/tmp/${JOBNAME}_del_supplier_list.tmp
                                                      
    cat $DD_SYSIN | tr -d "\r" > $DD_SYSOUT                                                      
                                                      
                                                      
#STEP Step030R 
    export STEPNAME=Step030R
    echo "    Start   ${STEPNAME}           "$(date)
#*--------------------------------------------------------------------------
#*  EXECUTE BATCH SQL CODE TO EITHER:                        
#*                                                                   
#*  IF "VERIFY" ENTERED IN 1ST REC OF PARM FILE -                  
#*  1) REPORT SUPPLIERS, ASSOC'D PART COUNT, AND EST RUN TIME.
#*                                                                   
#*  IF "DELETE" ENTERED IN 1ST REC OF PARM FILE -                  
#*  2) DELETE PARTS ASSOC'D TO SUPPLIERS AND PRODUCE REPORT. 
#*--------------------------------------------------------------------------                                                     
    export XAMUSERID=`cat $RACE/prm/zxampass.prm`     
    export PLSQLKSH=$RACE/bin/xam_del_supplier_sql.ksh 
    export ORA_IN_DIR=$OBJ_TMPDIR                       
    export ORA_IN_PARM=${JOBNAME}_del_supplier_list.tmp
    export ORA_RPT_DIR=$OBJ_RPTDIR                  
    export ORA_RPT_FILE=${JOBNAME}d_del_supplier_$(date +'%C%y%m%d%H%M%S').rpt
                                                      
    . $PLSQLKSH                                       


#STEP Step040  
    export STEPNAME=Step040 
    echo "    Start   ${STEPNAME}           "$(date)
#*--------------------------------------------------------------------------
#*  EMAIL REPORT TO MAPP DATA ANALYST
#*  2016/04 - replaced mailx with Mitchell Report Distribution system 
#*--------------------------------------------------------------------------                                                   
    #export MAIL_TEXT=$RACE/rpt/$ORA_RPT_FILE
    #export MAIL_PARM=$RACE/prm/xam001a.prm                                                  
    # get email address from parm card and send report                         
    #mail_recip="$(head -n +1 $MAIL_PARM | awk '{print $1}')"
    #mailx -s "xamr001 - Alt Part Supplier Deletion Run" $mail_recip < $MAIL_TEXT

    email_rpt.ksh "${JOBNAME}d"
    rpt_log_retention.ksh "${JOBNAME}d"   

#STEP Step999R
    export STEPNAME=Step999R
    echo "    Start   ${STEPNAME}           "$(date)
#*---------------------------------------------------------
#*       STEP999R   delete tmp datasets
#*---------------------------------------------------------

    rm -f $RACE/tmp/${JOBNAME}*

############################################################################
# END xam001.ksh                                                           #
############################################################################
