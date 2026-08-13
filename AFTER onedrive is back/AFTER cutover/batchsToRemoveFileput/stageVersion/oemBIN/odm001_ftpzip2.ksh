#!/bin/ksh
############################################################
#  Using manipulated directory list, get all files that    #
#  have been staged this month or last month on SPX server #
#                                                          #
#  NOTE: This ksh is concatenated with other scripts to    #
#  create an executable file.                              #
############################################################

ftp -n vw.servicesolutions.spx.com <<-END
user mitchellint vwaudi
binary
prompt no
verbose
lcd ${RACE}/../../oem_doc_repository/vw_audi/dat/original_source
