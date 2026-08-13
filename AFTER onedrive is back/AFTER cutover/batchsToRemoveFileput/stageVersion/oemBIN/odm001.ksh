#!/bin/ksh

  echo "$Id: odm001.ksh,v 1.15 2018/10/16 19:45:55 pg2697 Exp $"
############################################################################
#  PROCNAME:  odm001                                                       #
#  OEM DOCUMENT MANAGEMENT - VW/AUDI                                       #
############################################################################

  set -xv
  export PROCNAME=$(basename $0 .ksh_run)
  trap 'abndalrt.ksh    $?' err

  export RUNDATE=$(date +'%C%y%m%d%H%M%S')

  export MPTUSERID=`cat $RACE/prm/zmptpass.prm`
  export SQL_TMP_PATH=$OBJ_TMPDIR
  export SQL_RPT_PATH=$OBJ_RPTDIR

  export DOWNLOAD_DIR=${RACE}/../../oem_doc_repository/vw_audi/dat/original_source
  export PROCESSED_DIR=${RACE}/../../oem_doc_repository/vw_audi/dat/processed_source
  export ODM_RPT_DIR=${RACE}/../../oem_doc_repository/vw_audi/rpt
  export CONTROLS_DIR=${PROCESSED_DIR}/controls
  export HTML_DIR=${PROCESSED_DIR}/html
  export GRAPHICS_DIR=${PROCESSED_DIR}/graphics
  export OTHER_DIR=${PROCESSED_DIR}/other
  export PDF_DIR=${PROCESSED_DIR}/pdf
  export SGML_DIR=${PROCESSED_DIR}/sgml
  export XML_DIR=${PROCESSED_DIR}/xml  
  export RACE_RPT_DIR=${RACE}/rpt
  export RACE_TMP_DIR=${RACE}/tmp
  export RACE_LOG_DIR=${RACE}/log
  export UNZIP2_DIR=${RACE}/../../oem_doc_repository/vw_audi/tmp/unzip2
  export UNZIP3_DIR=${RACE}/../../oem_doc_repository/vw_audi/tmp/unzip3  

#STEP Step015R
#*********************************************************************************************************************
#* 1. Report and remove zip files that are empty
#* 
#*    NOTE: Files have been downloaded by RACE DataOps prior to job scheduling.
#*********************************************************************************************************************
  export STEPNAME=Step015R
  echo "    Start   ${STEPNAME}           "$(date)

  export BAD_ZIPLIST=$RACE/rpt/${JOBNAME}_bad_ziplist.rpt
  export MAIL_LIST=$RACE/prm/odm001_badfile_mail_recip.prm
  export MAIL_TEXT=$(more $RACE/prm/odm001_badfile_mail_msg.prm | awk '{print}')

  find ${RACE}/../../oem_doc_repository/vw_audi/dat/original_source -type f -size 0 -print > $BAD_ZIPLIST

  if [ ! -s $BAD_ZIPLIST ]
   then
     echo "Step015R NOTE: all zip files appear to be acceptible.\a"
   else
     while read LINE
     do 
       export RECIP=`echo $LINE | cut -f1`
       if [ ${ACT_LVL} = prod ]
       then
         echo $MAIL_TEXT | mailx -s "PRODUCTION - ODM Repository Update VW - Empty Zip File(s)"  ${RECIP}
       else
         echo $MAIL_TEXT | mailx -s "DEVELOPMENT - ODM Repository Update VW - Empty Zip File(s)"  ${RECIP}
       fi    
     done<$MAIL_LIST
     find ${RACE}/../../oem_doc_repository/vw_audi/dat/original_source -type f -size 0 -exec rm -f {} \;
  fi


#STEP Step020R
#*********************************************************************************************************************
#* 1. Get list of what's in "original_source" directory (after manual sftp) - zip files only
#*    Produce list based on files that have dates within past 45 days  (change to 14 days after deployment)
#* 2. Produce a list of just the zip file names for input to the next step
#*********************************************************************************************************************
  export STEPNAME=Step020R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORIG_LIST=$RACE/rpt/${JOBNAME}_orig_list.rpt
  export ORIG_FILES=$RACE/rpt/${JOBNAME}_orig_files.rpt

 #* Determine what's new or changed in "original_source" directory
  find $DOWNLOAD_DIR/*[zZ][iI][pP]* -type f -mtime -45 -exec ls -1 {} \; | sort -k1.58,1.250  >$ORIG_LIST
  
   sed /race/!d $ORIG_LIST | awk -F/ '{print $11 }' | sort -u > $ORIG_FILES


#STEP Step025R
#*********************************************************************************************************************
#* for each original source file -  
#* 1. Create a list of the zip files and what each contain 
#* 2. LEVEL 1 - UNZIP and COPY
#*    2a. Unzip files by directory type and place unzipped files in associated "processed_source" sub-directory
#*    2b. Copy any non-zip files that may be at this level as well.
#*    2c. If there are any zip files within the zip file, extract them to a tmp unzip2 directory. 
#* NOTE: Names are forced to all lowercase; otherwise you get duplicates and they're hard to find later.
#* *******************************************************************************************************************    
#* Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir]
#* Default action is to extract files in list, except those in xlist, to exdir; file[.zip] may be a wildcard.
#*    -l  => view the list of files in the zip file(s)
#*    -d  => extract files into exdir
#*    -j  => junk paths (do not make directories)
#*    -o  => overwrite files WITHOUT prompting
#*    -u  => update files, create if necessary
#*    -x  => exclude files that follow (in xlist)
#*    -LL => make all names lowercase
#*    -C  => match filenames case-insensitively
#* All files except graphics will be moved based on extensions referenced in "INCLUDE" parameters.
#* Graphics that have extensions will be moved based on extensions referenced in "INCLUDE" parameters but those
#* without an extension must be moved based on "EXCLUDE" parameters. (i.e. unzip everything EXCEPT these files)
#* *******************************************************************************************************************    
#* If step abends due to bad file -
#* Programmer:
#* 1. remove bad filename and all PRIOR file names from $RACE/rpt/${JOBNAME}_orig_files.rpt **
#*    ** zip_list and zip_status reports will still retain a record of ALL files that were processed so don't worry
#*       about this file getting modified.
#* 2. copy bad zip file to a  save area for you to look at it (and/or send it to SPX).
#* 3. remove bad zip file from original_source directory
#* 4. contact SPX re: bad zip file. Request they restage zip file or remove bad zip file from their ftp server.
#* Operations: 
#* 5. copy the updated file back to the \prod\race\oem\rpt directory.
#* 6. restart job at this step: odmr010.ksh Step025R
#*********************************************************************************************************************
  export STEPNAME=Step025R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORIG_FILES=$RACE/rpt/${JOBNAME}_orig_files.rpt
  export ZIPLIST=$RACE/rpt/${JOBNAME}_zip_list.rpt
  export ZIPSTATUS=$RACE/rpt/${JOBNAME}_zip_status.rpt
  touch $ZIPLIST
  touch $ZIPSTATUS

  while read LINE         
  do
    export FILE=`echo $LINE`
    export ZIPFILE=$DOWNLOAD_DIR/$FILE

    trap - err
    unzip -l "$ZIPFILE" > /dev/null 2>&1
    if [ $? != 0 ]
      then
      echo "error encountered during unzip of $ZIPFILE. It may be empty."
    else 
      unzip -l "$ZIPFILE" >> $ZIPLIST
      echo "unzipping $ZIP_NAME" 
    fi
    trap 'abndalrt.ksh    $?' err        

    #*********************************************************************************************************************
    #* LEVEL 1 - UNZIP and COPY
    #*********************************************************************************************************************
      
      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R CONTROLS - level 1 *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_control_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" $INCLUDE_FILES -d $CONTROLS_DIR >>$ZIPSTATUS
      trap 'abndalrt.ksh    $?' err


    #*  loop through control file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $CONTROLS_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R HTML - level 1     *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_html_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $HTML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through html file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $HTML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R GRAPHICS - level 1 *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_graphic_files.prm
      export INCLUDE_FILES=`cat $FILELIST`
      export EXCLUDE_FILES=`cat $RACE/prm/odm001_exclude_files_for_graphic.prm`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $GRAPHICS_DIR >> $ZIPSTATUS
      unzip -jouCLL "$ZIPFILE" -x ${EXCLUDE_FILES} -d $GRAPHICS_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through graphic file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $GRAPHICS_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R PDF - level 1      *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_pdf_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $PDF_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through pdf file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $PDF_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R SGML - level 1     *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_sgml_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $SGML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through sgml file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $SGML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R XML - level 1      *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_xml_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $XML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through xml file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $XML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R OTHER - level 1    *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_other_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $OTHER_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through other file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $DOWNLOAD_DIR/$FILE ]
          then
            echo "Step025R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $DOWNLOAD_DIR/$FILE $OTHER_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step025R UNZIP to level 2   *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_zip_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" $INCLUDE_FILES -d $UNZIP2_DIR >>$ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

  done<$ORIG_FILES

#STEP Step030R
#*********************************************************************************************************************
#* 1. Determine what's in "unzip2" directory
#* 2. Strip that list down to just the zip file names
#*********************************************************************************************************************
  export STEPNAME=Step030R
  echo "    Start   ${STEPNAME}           "$(date)

  export AFTER_ZIP2LIST=$RACE/rpt/${JOBNAME}_zip2_list.rpt

  export ORIG_DIFF=$RACE/tmp/${JOBNAME}_orig_diff.tmp
  export ZIP2_FILES=$RACE/rpt/${JOBNAME}_zip2_files.rpt

  find $UNZIP2_DIR -type f -exec ls -l {} \; | sort -k1.58,1.250  >$AFTER_ZIP2LIST


  sed /race/!d $AFTER_ZIP2LIST | awk -F/ '{print $11 }' > $ZIP2_FILES


#STEP Step035R
#*********************************************************************************************************************
#* for each zip2 level source file -  
#* 1. Create a list of the zip files and what each contain 
#* 2. LEVEL 2 - UNZIP and COPY
#*    2a. Unzip files by directory type and place unzipped files in associated "processed_source" sub-directory
#*    2b. Copy any files that may be at this level as well.
#*    2c. If there are any zip files within the zip file, extract them to a tmp unzip3 directory. 
#* *******************************************************************************************************************    
#* (see Step025R for info regarding unzip command usage)
#* *******************************************************************************************************************    
#* If step abends due to bad file -
#* 1. remove bad filename and all PRIOR file names from $RACE/rpt/${JOBNAME}_zip2_files.rpt
#*    ** zip_list and zip_status reports will still retain a record of ALL files that were processed so don't worry
#*       about this file getting modified.
#* 2. copy bad zip file to a  save area for you to look at it (and/or send it to SPX).
#* 3. contact SPX re: bad zip file. Request they restage zip file or remove bad zip file from their ftp server.
#* Operations: 
#* 4. copy the updated file back to the \prod\race\oem\rpt directory.
#* 5. restart job at this step: odmr010.ksh Step035R
#*********************************************************************************************************************
  export STEPNAME=Step035R
  echo "    Start   ${STEPNAME}           "$(date)

  export ZIP2_FILES=$RACE/rpt/${JOBNAME}_zip2_files.rpt
  export ZIPLIST=$RACE/rpt/${JOBNAME}_zip_list.rpt
  export ZIPSTATUS=$RACE/rpt/${JOBNAME}_zip_status.rpt

  while read LINE
  do
    export FILE=`echo $LINE`
    export ZIPFILE=$UNZIP2_DIR/$FILE
    unzip -l "$ZIPFILE" >> $ZIPLIST

    #*********************************************************************************************************************
    #* LEVEL 1 - UNZIP and COPY
    #*********************************************************************************************************************

      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R CONTROLS - level 2 *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_control_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" $INCLUDE_FILES -d $CONTROLS_DIR >>$ZIPSTATUS
      trap 'abndalrt.ksh    $?' err


    #*  loop through control file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $CONTROLS_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R HTML - level 2     *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_html_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $HTML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through html file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $HTML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R GRAPHICS - level 2 *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_graphic_files.prm
      export INCLUDE_FILES=`cat $FILELIST`
      export EXCLUDE_FILES=`cat $RACE/prm/odm001_exclude_files_for_graphic.prm`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $GRAPHICS_DIR >> $ZIPSTATUS
      unzip -jouCLL "$ZIPFILE" -x ${EXCLUDE_FILES} -d $GRAPHICS_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through graphic file list, issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $GRAPHICS_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R PDF - level 2      *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_pdf_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $PDF_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through pdf file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $PDF_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R SGML - level 2     *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_sgml_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $SGML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through sgml file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $SGML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R XML - level 2      *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_xml_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $XML_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through xml file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $XML_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R OTHER - level 2    *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_other_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" ${INCLUDE_FILES} -d $OTHER_DIR >> $ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

    #*  loop through other file list,  issuing copy command for any files having that file type / extension)
      while read LINE
      do
        export FILE=`echo $LINE | cut -f1`
        if [ ! -s $UNZIP2_DIR/$FILE ]
          then
            echo "Step035R NOTE: No $FILE files to be copied." >> $ZIPSTATUS
          else
            cp $UNZIP2_DIR/$FILE $OTHER_DIR >> $ZIPSTATUS
        fi
      done<$FILELIST


      echo "*********************************" >> $ZIPSTATUS
      echo "*** Step035R UNZIP to level 3   *" >> $ZIPSTATUS
      echo "*********************************" >> $ZIPSTATUS

      export FILELIST=$RACE/prm/odm001_zip_files.prm
      export INCLUDE_FILES=`cat $FILELIST`

    #*  turn error trapping off during unzip because it raises a return code of 11
      trap - err
      unzip -jouCLL "$ZIPFILE" $INCLUDE_FILES -d $UNZIP3_DIR >>$ZIPSTATUS
      trap 'abndalrt.ksh    $?' err

  done<$ZIP2_FILES

#STEP Step040R
#*********************************************************************************************************************
#* 1. Check if anything was unzipped to level 3 (shouldn't be)
#*********************************************************************************************************************
  export STEPNAME=Step040R
  echo "    Start   ${STEPNAME}           "$(date)

  if [ "$(ls -A $UNZIP3_DIR)" ]; then
      echo "Step040R ALERT!!!! Files were unzipped to level 3 tmp. Sub-script must be modified to handle these!"
      $(abndalrt.ksh 9)
  else
    echo "Step040R: No files unzipped to level 3 tmp. (This is good!)"
  fi


#STEP Step050R
#*********************************************************************************************************************
#* 1. No matter what, catalog files seem to land up in graphics directory (when they should wind up in control) so....
#*    MOVE them there!!
#*********************************************************************************************************************
  export STEPNAME=Step050R
  echo "    Start   ${STEPNAME}           "$(date)

  if [ ! -s $GRAPHICS_DIR/catalog* ]
    then
      echo "Step050R NOTE: No control files to be moved."
    else
      mv $GRAPHICS_DIR/catalog* $CONTROLS_DIR
  fi


#STEP Step060R
#*********************************************************************************************************************
#* 1. Create a list of everything in the processed directories after the unzips and copies
#*    (This list will be used to update the Oracle ODM_FILE table to identify files that have been changed or added.)
#*********************************************************************************************************************
  export STEPNAME=Step060R
  echo "    Start   ${STEPNAME}           "$(date)

  export PROCESSED_DAT=$RACE/dat/${JOBNAME}_xtab_odm_processed_list.dat

  find $PROCESSED_DIR -type f -exec ls -l {} \; > $PROCESSED_DAT


#STEP Step065R
#*********************************************************************************************************************
#* 1. Update Oracle ODM_FILE table using processed file list
#*********************************************************************************************************************
  export STEPNAME=Step065R
  echo "    Start   ${STEPNAME}           "$(date)

export PROC_SUM=$RACE/rpt/${JOBNAME}_proc_summary.rpt 
export PROC_DTL=$RACE/rpt/${JOBNAME}_proc_detail.rpt  

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_ODM_SYSTEM.P_ODM_FILE_LOGGING('vw_audi','${ACT_LVL}','$SQL_RPT_PATH','$PROC_SUM','$PROC_DTL');

QUIT;
%

#STEP Step070R
#*********************************************************************************************************************
#* 1. Grep file for 'Archive' to obtain names of all archive files included in this update. 
#* 2. Add the list to the proc_detail report.   
#*********************************************************************************************************************
  export STEPNAME=Step070R
  echo "    Start   ${STEPNAME}           "$(date)

  cat $RACE/rpt/${JOBNAME}_proc_summary.rpt >> $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt

  echo "  " >> $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt 
  echo "  " >> $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt
  echo "  " >> $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt

  echo "ZIP FILES ASSOCIATED WITH THIS RUN:" >> $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt
  grep 'Archive:' $RACE/rpt/${JOBNAME}_zip_status.rpt | sort -u >>  $RACE/rpt/${JOBNAME}_proc_summary_mod.rpt

  rm -f $RACE/rpt/${JOBNAME}_proc_summary.rpt

#*********************************************************************************************************************
#* Steps 100 thru 190 - Rename all files created in this run to GDG'S (so they can be referenced in future runs and
#*                      so that they can be removed using file "colling"). 
#*********************************************************************************************************************

#STEP Step100R
  export STEPNAME=Step100R
  echo "    Start   ${STEPNAME}           "$(date)

  export AFTER_ORIGLIST_1=$RACE/rpt/${JOBNAME}_orig_list.rpt
  export AFTER_ORIGLIST_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_orig_list.rpt(+1)" NEW 12)

  mv $AFTER_ORIGLIST_1 $AFTER_ORIGLIST_2

#STEP Step110R
  export STEPNAME=Step110R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORIG_FILES_1=$RACE/rpt/${JOBNAME}_orig_files.rpt
  export ORIG_FILES_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_orig_files.rpt(+1)" NEW 12)

  mv $ORIG_FILES_1 $ORIG_FILES_2

#STEP Step120R
  export STEPNAME=Step120R
  echo "    Start   ${STEPNAME}           "$(date)

  export ZIPSTATUS_1=$RACE/rpt/${JOBNAME}_zip_status.rpt
  export ZIPSTATUS_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_zip_status.rpt(+1)" NEW 12)

  mv $ZIPSTATUS_1 $ZIPSTATUS_2


#STEP Step130R
  export STEPNAME=Step130R
  echo "    Start   ${STEPNAME}           "$(date)

  export PROC_DAT=$RACE/dat/${JOBNAME}_xtab_odm_processed_list.dat
  export PROC_RPT=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_xtab_odm_processed_list.rpt(+1)" NEW 12)

  mv $PROC_DAT $PROC_RPT


#STEP Step140R
  export STEPNAME=Step140R
  echo "    Start   ${STEPNAME}           "$(date)

  export ZIP2LIST_1=$RACE/rpt/${JOBNAME}_zip2_list.rpt
  export ZIP2LIST_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_zip2_list.rpt(+1)" NEW 12)

  mv $ZIP2LIST_1 $ZIP2LIST_2

#STEP Step150R
  export STEPNAME=Step150R
  echo "    Start   ${STEPNAME}           "$(date)

  export ZIP2_FILES_1=$RACE/rpt/${JOBNAME}_zip2_files.rpt
  export ZIP2_FILES_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_zip2_files.rpt(+1)" NEW 12)

  mv $ZIP2_FILES_1 $ZIP2_FILES_2


#STEP Step160R
  export STEPNAME=Step160R
  echo "    Start   ${STEPNAME}           "$(date)

  export ZIPLIST_1=$RACE/rpt/${JOBNAME}_zip_list.rpt
  export ZIPLIST_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_zip_list.rpt(+1)" NEW 12)

  mv $ZIPLIST_1 $ZIPLIST_2

#STEP Step170R
  export STEPNAME=Step170R
  echo "    Start   ${STEPNAME}           "$(date)

  export BAD_ZIPLIST_1=$RACE/rpt/${JOBNAME}_bad_ziplist.rpt
  export BAD_ZIPLIST_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_bad_ziplist.rpt(+1)" NEW 12)

  mv $BAD_ZIPLIST_1 $BAD_ZIPLIST_2

#*********************************************************************************************************************
#* Some files are copied to oem repository (just in case Serge should want to view them) as well as saved in unix.
#*********************************************************************************************************************

#STEP Step180R
  export STEPNAME=Step180R
  echo "    Start   ${STEPNAME}           "$(date)

  export PROC_SUM_1=$RACE/rpt/${JOBNAME}_proc_summary_mod.rpt
  export PROC_SUM_CRLF=$RACE/tmp/${JOBNAME}_proc_summary.tmp
  export PROC_SUM_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_proc_summary.rpt(+1)" NEW 12)

  awk 'sub("$", "\r")' ${PROC_SUM_1}  > ${PROC_SUM_CRLF}
  cp $PROC_SUM_CRLF $ODM_RPT_DIR/${JOBNAME}_proc_summary_${RUNDATE}.rpt 
  mv $PROC_SUM_1 $PROC_SUM_2


#STEP Step190R
  export STEPNAME=Step190R
  echo "    Start   ${STEPNAME}           "$(date)

  export PROC_DTL_1=$RACE/rpt/${JOBNAME}_proc_detail.rpt 
  export PROC_DTL_CRLF=$RACE/tmp/${JOBNAME}_proc_detail.tmp 
  export PROC_DTL_2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_proc_detail.rpt(+1)" NEW 12)

  awk 'sub("$", "\r")' ${PROC_DTL_1}  > ${PROC_DTL_CRLF}
  cp $PROC_DTL_CRLF $ODM_RPT_DIR/${JOBNAME}_proc_detail_${RUNDATE}.rpt 
  mv $PROC_DTL_1 $PROC_DTL_2


#STEP Step200R
#*********************************************************************************************************************
#* Update ODM_FILE, ODM_FILE_VEHICLE, ODM_FILE_GRAPHIC, and ODM_FILE_CONTENTS tables with information obtained from SGML files.
#* 1. Create a list of all sgml files.
#* 2. For each sgml file in sgml_list.tmp -  
#*    2a. copy file to tmp directory (so that Oracle can read it from an existing Oracle directory object)
#*        fold ensures that record length doesn't exceed input record length declared in procedure
#*    2b. execute the analysis program (which will update the Oracle tables)
#*    2c. remove file from tmp directory
#*********************************************************************************************************************
  export STEPNAME=Step200R
  echo "    Start   ${STEPNAME}           "$(date)

export SGML_LIST=$RACE/tmp/${JOBNAME}_sgml_list.tmp

ls -1 $SGML_DIR > $SGML_LIST

while read LINE
do

export FILENAME=`echo $LINE | cut -f1`
fold -w 998 $SGML_DIR/$FILENAME > $RACE_TMP_DIR/$FILENAME
 
sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec SP_ODM_SGML_ANALYSIS_VW('vw_audi','$SQL_TMP_PATH','$FILENAME');

QUIT;
%

rm -f $RACE_TMP_DIR/$FILENAME 

done<$SGML_LIST

#STEP Step210R
#*********************************************************************************************************************
#* Update ODM_FILE, ODM_FILE_VEHICLE, ODM_FILE_GRAPHIC, and ODM_FILE_CONTENTS tables with information obtained from XML files.
#* 1. Create a list of all xml files.
#* 2. For each xml file in xml_list.tmp -  
#*    2a. copy file to tmp directory (so that Oracle can read it from an existing Oracle directory object)
#*        fold ensures that record length doesn't exceed input record length declared in procedure
#*    2b. execute the analysis program (which will update the Oracle tables)
#*    2c. remove file from tmp directory
#*********************************************************************************************************************
  export STEPNAME=Step210R
  echo "    Start   ${STEPNAME}           "$(date)

export XML_LIST=$RACE/tmp/${JOBNAME}_xml_list.tmp

ls -1 $XML_DIR > $XML_LIST

while read LINE
do

export FILENAME=`echo $LINE | cut -f1`
fold -w 998 $XML_DIR/$FILENAME > $RACE_TMP_DIR/$FILENAME
 
sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec SP_ODM_XML_ANALYSIS_VW('vw_audi','$SQL_TMP_PATH','$FILENAME');

QUIT;
%

rm -f $RACE_TMP_DIR/$FILENAME 

done<$XML_LIST


#STEP Step220R
#*********************************************************************************************************************
#* Update ODM_FILE and ODM_FILE_VEHICLE tables with information obtained from PDF filenames.
#*********************************************************************************************************************
  export STEPNAME=Step220R
  echo "    Start   ${STEPNAME}           "$(date)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec SP_ODM_PDF_ANALYSIS_VW('vw_audi');

QUIT;
%

#STEP Step300R
#*********************************************************************************************************************
#* 1. Run PL/SQL procedure to produce reports that:
#*    - list all files received to date
#*    - list all missing graphic files
#* 2. Add CRLF and copy reports to ODM Repository's report directory
#* 3. Change name to permanent gdg in OEM report directory
#*********************************************************************************************************************
  export STEPNAME=Step300R
  echo "    Start   ${STEPNAME}           "$(date)

  export DTL_RPT1=$RACE/rpt/${JOBNAME}_all_files.rpt
  export DTL_CRLF=$RACE/tmp/${JOBNAME}_all_files.tmp 
  export DTL_RPT2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_all_files.rpt(+1)" NEW 12)

  export MISS_RPT1=$RACE/rpt/${JOBNAME}_missing_file.rpt
  export MISS_CRLF=$RACE/tmp/${JOBNAME}_missing_file.tmp 
  export MISS_RPT2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_missing_files.rpt(+1)" NEW 12)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec sp_odm_file_reports('vw_audi','$SQL_RPT_PATH','$DTL_RPT1','$MISS_RPT1');

QUIT;
%

  awk 'sub("$", "\r")' ${DTL_RPT1}  > ${DTL_CRLF}
  cp $DTL_CRLF $ODM_RPT_DIR/${JOBNAME}_all_files_${RUNDATE}.rpt 
  mv $DTL_RPT1 $DTL_RPT2

  awk 'sub("$", "\r")' ${MISS_RPT1}  > ${MISS_CRLF}
  cp $MISS_CRLF $ODM_RPT_DIR/${JOBNAME}_missing_files_${RUNDATE}.rpt 
  mv $MISS_RPT1 $MISS_RPT2
                                                                                                                                                 
                                                                                                                                                 
#STEP Step310R
#*********************************************************************************************************************
#* 1. Run PL/SQL Analyzer process to create list of sgml files needing conversion. 
#*    (Compare last_update_date to last_convert_date for all sgml files.)
#* 2. Copy report to ODM Repository's report directory **
#*    ** Carriage return and line feed are added to the file. Since it is not being ftp'd to an NT environment (which 
#*       would add these), we must add them before placing the file in the CIFS-shared directory. 
#* 3. Change name to permanent gdg in OEM report directory
#*
#*
#* After this job completes, a future enhancement will be:
#* 1. Run sgml-to-xml conversion utility.   (This will be run in Windows environment - after this job ends.)
#* 2. Run PL/SQL process to update last_converted_date in ODR_File table. (This will be run in unix after windows job completes.)
#*********************************************************************************************************************
  export STEPNAME=Step310R
  echo "    Start   ${STEPNAME}           "$(date)

  export CONV_RPT1=$RACE/rpt/${JOBNAME}_sgmls_for_convert.rpt
  export CONV_CRLF=$RACE/tmp/${JOBNAME}_sgmls_for_convert.tmp 
  export CONV_RPT2=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_sgmls_for_convert.rpt(+1)" NEW 12)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec sp_odm_sgml_files_to_convert('vw_audi','$SQL_RPT_PATH','$CONV_RPT1');

QUIT;
%

    if [ ! -s $CONV_RPT1 ]
    then
        echo "NOTE: No SGML Conversion List to be copied this time.\a"
    else
        awk 'sub("$", "\r")' ${CONV_RPT1} > ${CONV_CRLF}
        cp $CONV_CRLF $ODM_RPT_DIR/${JOBNAME}_sgmls_for_convert.rpt 
        mv $CONV_RPT1 $CONV_RPT2
    fi


#STEP Step800R
#*********************************************************************************************************************
#* 1. Email DBA that job is complete
#*********************************************************************************************************************
  export STEPNAME=Step800R
  echo "    Start   ${STEPNAME}           "$(date)

  export MAIL_LIST=$RACE/prm/odm001_mail_recip.prm
  export FTP_TEXT=$(more $RACE/tmp/${JOBNAME}_proc_summary.tmp | awk '{print}' )

while read LINE
do 
  export RECIP=`echo $LINE | cut -f1`
  if [ ${ACT_LVL} = prod ]
  then
    echo $FTP_TEXT | mailx -s "PRODUCTION - ODM Repository Update VW"  ${RECIP}
  else
    echo $FTP_TEXT | mailx -s "DEVELOPMENT - ODM Repository Update VW"  ${RECIP}
  fi    
done<$MAIL_LIST


#STEP Step900R
#*********************************************************************************************************************
#* 1. Remove reports from ODM Repository "rpt" directory that are older than 31 days 
#*********************************************************************************************************************
export STEPNAME=Step900R
echo "    Start   ${STEPNAME}           "$(date)

trap '' err
find ${RACE}/../../oem_doc_repository/vw_audi/rpt -type f -mtime +31 -exec rm -f {} \;
trap 'abndalrt.ksh    $?' err

#STEP Step910R
#*********************************************************************************************************************
#* 1. Remove "original_source" files that are older than 14 days
#*********************************************************************************************************************
#export STEPNAME=Step910R
#echo "    Start   ${STEPNAME}           "$(date)

trap '' err
find ${RACE}/../../oem_doc_repository/vw_audi/dat/original_source -type f -mtime +14 -exec rm -f {} \;
trap 'abndalrt.ksh    $?' err

#STEP Step999R
#*********************************************************************************************************************
#* 1. Remove temp files
#*********************************************************************************************************************
  export STEPNAME=Step999R
  echo "    Start   ${STEPNAME}           "$(date)

  rm -f $RACE/tmp/${JOBNAME}*  
  
  trap '' err
  find ${RACE}/../../oem_doc_repository/vw_audi/tmp/unzip2 -type f -mtime +0 -exec rm -f {} \;
  trap 'abndalrt.ksh    $?' err

  trap '' err
  find ${RACE}/../../oem_doc_repository/vw_audi/tmp/unzip3 -type f -mtime +0 -exec rm -f {} \;
  trap 'abndalrt.ksh    $?' err

# END-OF-SCRIPT ******************************************************
