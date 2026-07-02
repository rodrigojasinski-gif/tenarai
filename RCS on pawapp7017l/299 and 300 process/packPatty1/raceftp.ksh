#!/bin/ksh
#$Id: raceftp.ksh,v 1.5 2021/10/27 20:11:01 pg2697 Exp $
###########################################################################
#
#   DESCRIPTION
#   Called by raceprofile.ksh and Batch Job Master Scripts
#   to build FTP related environment variables
#
###########################################################################
# 06/12/2007:  GW Hardcode the full server name prod3nt.mitchell.com for
#              more efficient connections and to prevent timeouts.
#              Note there is no server alias available at this time.
# 04/19/2012   GW Modify FTP_SITE from ftp.mitchell.com to ftp-ssh.mitchell.com
# 10/26/2021: pag - Change prod3nt domain name
############################################################################

export FTP_SITE=ftp-ssh.mitchell.com
export FTP_SERVER=prod3nt.production.int
export FTP_BUSINESS_PATH=/ftp1/Business_Partners

# Change rj132422 - 20251023
export FTP_MITCHELL_BUSINESS_PATH=/prod/data/ftp/Business_Partners/mitchell

THISHOST=$(hostname -s)

if [ $ACT_LVL = "prod" ]
then
   PRODHOST=$(hostname -s)
   TESTHOST="TESTHOSTgoesHERE"
else
   PRODHOST="PRODHOSTgoesHERE"
   TESTHOST=$(hostname -s)
fi

export THISHOST
export PRODHOST
export TESTHOST

###########################################################################
# END raceftp.ksh
###########################################################################
