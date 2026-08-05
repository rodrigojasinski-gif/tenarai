#!/bin/ksh
#$Id$
############################################################################
#  altp_ftp_data.ksh                                                       #
#                                                                          #
#  CONFIGURABLE base path for MAPP/ALTP file exchange.                     #
#  Sourced by the ALTP batch scripts (xamref.ksh, xamupd.ksh, xamrpt.ksh,  #
#  xam200.ksh, xam001.ksh, xam010.ksh, xam030.ksh, xam069.ksh).            #
#                                                                          #
#  Replaces the legacy prod3nt / ${NOVELL} FTP dependency with a local     #
#  NFS-mounted path. The prod3nt server is being decommissioned.           #
#                                                                          #
#  Change rj132422 - 20260424 - AES-XXXX                                   #
############################################################################
#                                                                          #
#  *********************************************************************** #
#  ***  TO CHANGE THE LOCATION: edit ONLY the ALTP_FTP_DATA line below  *** #
#  *********************************************************************** #
#                                                                          #
############################################################################

# --- THE ONLY LINE YOU NEED TO CHANGE -------------------------------------
#
# TEMPORARY test location - a subfolder inside the existing
# OEM_Repair_Doc_Repository NFS mount, used until the dedicated NAS share
# for ftp_data is provisioned and a final path is confirmed.
#
# When the final NAS share is ready, replace the line below with the final
# path, for example:
#     export ALTP_FTP_DATA=/nas/ftp_data/${ACT_LVL}
#
export ALTP_FTP_DATA=/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev
#
# --------------------------------------------------------------------------

# --- Derived sub-paths - normally no need to change these -----------------
export ALTP_DIR=${ALTP_FTP_DATA}/altp
export ALTP_NAPA_DIR=${ALTP_FTP_DATA}/altp/NAPA
export ALTP_INTRPT_DIR=${ALTP_FTP_DATA}/altp/Internal_Rpts
export ALTP_CUSTRPT_DIR=${ALTP_FTP_DATA}/altp/Customer_Rpts

############################################################################
#  END altp_ftp_data.ksh                                                   #
############################################################################
