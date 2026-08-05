#!/bin/ksh
############################################################################
#  setup_test_env.sh                                                       #
#                                                                          #
#  One-time setup helper for the ALTP/MAPP E2E test on RADD (dawapp7017l). #
#  Creates the folder structure inside the TEMPORARY test location and     #
#  verifies it. Safe to re-run - mkdir -p is idempotent.                   #
#                                                                          #
#  Change rj132422 - 20260424 - AES-XXXX                                   #
############################################################################

# Must match ALTP_FTP_DATA in altp_ftp_data.ksh
ALTP_FTP_DATA=/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev

echo "=== Creating ALTP test folder structure under: ${ALTP_FTP_DATA} ==="

mkdir -p ${ALTP_FTP_DATA}/altp/NAPA
mkdir -p ${ALTP_FTP_DATA}/altp/Internal_Rpts
mkdir -p ${ALTP_FTP_DATA}/altp/Customer_Rpts

echo
echo "=== Verifying structure ==="
ls -la ${ALTP_FTP_DATA}/altp/

echo
echo "=== Write test ==="
TESTFILE=${ALTP_FTP_DATA}/altp/.write_test_$$
if echo "write test" > ${TESTFILE} 2>/dev/null
then
    echo "OK - write permission confirmed on ${ALTP_FTP_DATA}/altp/"
    rm -f ${TESTFILE}
else
    echo "ERROR - cannot write to ${ALTP_FTP_DATA}/altp/ - check NFS mount and permissions"
    exit 1
fi

echo
echo "=== Setup complete ==="
echo "Next step: place keystone_combined.txt into ${ALTP_FTP_DATA}/altp/"
