#!/bin/ksh
echo $Id: oem_ref_pptr075_isu_merge_source_files.ksh,v 1.2 2007/12/21 20:23:22 jw97143 Exp $
#***************************************************************************
#  PROCNAME: oem_ref_pptr075_isu_merge_source_files.ksh
#***************************************************************************
set -xv
trap 'oem_abndalrt.ksh $?' err

cat ${RACE}/dat/pptr075_xtab_oem_ref_pptr075_isu_raw.dat    > ${RACE}/dat/pptr075_xtab_oem_ref_pptr075_isu_raw.dat
cat ${RACE}/dat/pptr075_xtab_oem_ref_pptr075_isu_raw_2.dat >> ${RACE}/dat/pptr075_xtab_oem_ref_pptr075_isu_raw.dat


#*****************************************************************************************************************
# END 
#*****************************************************************************************************************
