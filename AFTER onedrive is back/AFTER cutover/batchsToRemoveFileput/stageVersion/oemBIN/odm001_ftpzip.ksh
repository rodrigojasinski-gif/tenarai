#!/bin/ksh
############################################################
#  Get list of all files in SPX (vw_audi) web site         #
############################################################

ftp -n vw.servicesolutions.spx.com <<-END
user mitchellint vwaudi
binary
prompt no
verbose
lcd ${RACE}/../../oem_doc_repository/vw_audi/dat/original_source
dir ./ ftplist.tmp
bye
END

########################################
# END OF SCRIPT                        #
########################################

