ls -ltr
cd /prod/race/oem/log && ls -ltr
cat mptr299_20260708121637.log
export PATH=/prod/race/share/bin/:/prod/race/oem/bin/:$PATH && export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin && export TWO_TASK=RADP.MITCHELL.COM
ls -ltr
cat mptr299_20260708122159.log
sqlplus -s race/na5car <<'SQL'
SET LINESIZE 150 PAGESIZE 50
COL object_name FORMAT A30
COL object_type FORMAT A14
SELECT object_name, object_type, status, last_ddl_time
  FROM all_objects
 WHERE object_name = UPPER('PKG_COMMON_UTILITIES') 
   AND object_type IN ('PACKAGE','PACKAGE BODY')
 ORDER BY object_type;
SQL

sqlplus -s race/na5car
echo $TWO_TASK
export PATH=/prod/race/share/bin/:/prod/race/oem/bin/:$PATH && export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin && export TWO_TASK=RADP.MITCHELL.COM
sqlplus -s race/na5car <<'SQL'
SET LINESIZE 150 PAGESIZE 50
COL object_name FORMAT A30
COL object_type FORMAT A14
SELECT object_name, object_type, status, last_ddl_time
  FROM all_objects
 WHERE object_name = UPPER('PKG_COMMON_UTILITIES') 
   AND object_type IN ('PACKAGE','PACKAGE BODY')
 ORDER BY object_type;
SQL

sqlplus -s race/na5car
sqlplus -s rj132422/Lapdska98#qwe
cd /prod/ftdata
cd prod
cd /prod/ftp_data
exit
pwd
cd /prod
cd ftp_data
cd /race
ls
cd race
ls
ls -la
cd oem
ls
ls -la
cd ..
ls
ls -la
pwd
ls -la
cd altp
ls
ls -la
cd test1
ls
ls -la
more test1
ls
cd ..
ls
cd ..
ls
cd odd
ls
ls -la
pwd
ls
ls -la
cd race
ls
xit
exit
cd /prod/ftp_data
exit
cd $olog
pwd
cd /prod/race/oem/log && ls -ltr
cat mptr299_20260708122159.log
cd /prod/ftdata
df -h
cd /prod/ftp_data
cd /prod/race
ls
cd /prod/ftp_data
exit
ls -ld /prod/odd
cd /prod
ls
ls -l
cd ftp_data
exit
df -h
ls -l /prod/race
exit
ls -l /prod/race
df -h
ls -l /prod/ftp_data
cd /prod/
ls
cd ftp_data
cd race
ls -l
ls
cd /prod/ftp_data
ls
ls -la
cd prod
ls
ls -la
cd oem
ls
ls -la | more
 cd ..
ls
cd /prod/ftp_data
ls
ls -la
cd mdev
ls
ls -la
cd /prod/ftp_data
ls
ls -la
cd prod
ls
cd oem
ls
ls -la |more
touch thisisatestfile.txt
ls
rm thisisatestfile.txt
ls
pwd
exit
ls
cd /prod
ls
ls -la
cd race
ls
cd ..
ls
cd odd
ls
cd ftp_data
ls
ls -la
cd prod
ls
cd race
ls
cd ..
ls
cd /
ls
ls -la
cd home
ls
cd corp.int
ls
ls -la
cd ..
ls
ls -la
cd ~
pwd
ls
ls -la
df -k
cd /nas/prod/
ls
ls -la
cd  OEM_Repair_Doc_Repository
cd /nas/prod/ OEM_Repair_Doc_Repository
exit
 cd /nas/prod/OEM_Repair_Doc_Repository
exit
cd /prod
ls
ls -la
cd ftp_data
ls
cd prod
ls
ls -la
cd oem
ls
ls -la
clear
ls -la | more
ls
cd cdprod02 (prod3nt) (X) - Shortcut.lnk
cd 'cdprod02 (prod3nt) (X) - Shortcut.lnk'
ls -la
df -k
cd /prod/race
ls
ls -la
cd oem
ls
ls -la
cd prm
ls
cd ..
ls
ls -la
cd src
ls
cd ..
ls
cd ..
ls
df -k
cd /nas/race/micdata
cd /prod/odd
cd /nas/prod
ls
cd OEM_Repair_Doc_Repository
df -k
cd /prod/ftp_data
ls
ls -la
cd mdev
ls
ls -la
cd oem_research
ls
cd ..
cd oem
ls
 cd /nas/prod/OEM_Repair_Doc_Repository
cd /nas/race/micdata
ls
cd /prod/odd
ls
cd /prod/race
ls
ls la
df -k
cd /prod/ftp_data
ls
unama -a
who
cd ~
ls
cd /prod/ftp_data
clear
ls
ls -la
sftp ftp-ssh.mitchell.com
exit
ls -l /prod/ftp_data
cd /prod/ftp_data
ls -l
cd prod
ls
ls -l
exit
sftp race_b1@ftp-ssh.mitchell.com
exit
cd /prod/ftp_data
ls
ls -la
cd prod
ls
cd ..
ls
cd mdev
ls
cd oem
ls
cd ~
ls
df -k
cd /nas/prod/OEM_Repair_Doc_Repository
exit
cd /prod/race
ls
ls -al
df -h
cd /mdev
ls -l
cd /tmp
vi t
for i in `cat t`; do  ls -l $i ; done 
cd /prod/race
cd rxt
cd ext
ls
pwd
cd tmp
ls -l
touch t
rm t
exit
ls -l /prod/race/ext
ls -l /prod/race/oem
ls -l /prod/race/altp
ls -l /prod/race/dbadmin
cd /prod/race
touch t
exit
cd /prod/race/oem/log && ls -ltr
rm teste_rodrigo123.log
ls -ltr
cat mptr299_20260709121123.log
tail -f mptr299_20260709121123.log
ssh -l sshacs@tesladata.upload.akamai.com
ssh tesladata.upload.akamai.com
tail -f mptr299_20260709121123.log
cat /prod/race/oem/tmp/mptr299_sftp__log_20260709121127.tmp
ls -ltr /prod/race/oem/tmp/mptr299_sftp__log_20260709121127.tmp
cat /prod/race/oem/tmp/mptr299_sftp__log_20260709121127.tmp
cat mptr299_20260709121123.log
ls -ltr
cat mptr299_20260709130742.log
cd /tmp
cd ..
ls -ltr
cd /tmp
touch test.txt
cat aaa > test.txt 
echo aaa > test.t
echo aaa > test.txt 
cat test.txt 
cd /prod/race/oem/tmp
cd /prod/race
cd oem
ls
ls -ltr
pwd
cd ../ext
ls -ltr
cd ../share
ls -ltr
cd ..
cd share
find . -type d -name tmp
cd ..
find . -type d -name tmp
cd oem
ls -ltr
mkdir tmp
ls -ltr
cd tmp
mv /tmp/test.txt .
ls 
cat test.txt 
export PATH=/prod/race/share/bin/:/prod/race/oem/bin/:$PATH && export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin && export TWO_TASK=RADP.MITCHELL.COM
cd /prod/race/oem/bin/ && mptr299.ksh
cat mptr299.ksh
pwd
which race_oem.ksh
cat /prod/race/share/bin/race_oem.ksh
which raceftp.ksh
cat /prod/race/share/bin/raceftp.ksh
cd /prod
ls
cd ftp_data
ls
ls -l
cd mdev
ls
cd oem
ls -l
cd../pord
cd ../pord
ls
ls -l
cd /prod
ls
cd data
cd ftp_data
ls
cd mdev
ls
pwd
cd /prod
cd race
ls
ls -l
cd oem
ls -l
pwd
cd log
ls -lt|more
cat mptr299_20260709130742.log
which fileget.ksh
ls -lt|more
cd /prod/race/oem/log && ls -ltr
cat mptr299_20260709130742.log
which oem_ref_mptr299_ftp_tesla_source_file.ksh
export PATH=/prod/race/share/bin/:/prod/race/oem/bin/:$PATH && export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin && export TWO_TASK=RADP.MITCHELL.COM
which oem_ref_mptr299_ftp_tesla_source_file.ksh
cat /prod/race/oem/bin/oem_ref_mptr299_ftp_tesla_source_file.ksh
which raceftp.ksh
cat /prod/race/share/bin/raceftp.ksh
/prod/race/share/bin/prod_move raceftp.ksh share/bin
cat /prod/race/share/bin/raceftp.ksh
which oem_ref_mptr299_ftp_tesla_source_file.ksh
cat /prod/race/oem/bin/oem_ref_mptr299_ftp_tesla_source_file.ksh
/prod/race/share/bin/prod_move oem_ref_mptr299_ftp_tesla_source_file.ksh oem/bin
 cat /prod/race/oem/bin/oem_ref_mptr299_ftp_tesla_source_file.ksh
grep -i rj132422  /prod/race/oem/bin/oem_ref_mptr299_ftp_tesla_source_file.ksh
cd /prod/race/oem/dat
ls -ltr
exit
sftp cf2446@ftp-ssh.mitchell.com
exit
cd /tmp
ls -ltr
cp mptr299_xftp_tesla.zipped /prod/race/oem/dat
cd /prod/race/oem/dat
ls -ltr
pwd
history | grep -i 299
cd /prod/race/oem/bin/ && mptr299.ksh
cd /prod/race/oem/bin/
 mptr299.ksh
which race_oem.ksh
export PATH=/prod/race/share/bin/:/prod/race/oem/bin/:$PATH && export TNS_ADMIN=/u01/app/oracle/product/19.3.0/client64/network/admin && export TWO_TASK=RADP.MITCHELL.COM
which race_oem.ksh
cd /prod/race/oem/bin/ && mptr299.ksh
cd /prod/race/oem/log && ls -ltr
cat mptr299_20260710090928.log
cd ..
pwd
cd bin
sed -i 's/\r$//' $(command -v oem_ref_mptr299_ftp_tesla_source_file.ksh)
cd /prod/race/oem/bin/ && mptr299.ksh
cd /prod/race/oem/log && ls -ltr
cat mptr299_20260710091351.log
sudo su - svc-apd-race-prd@production.int
ls -ltr
cp mptr299_20260710091351.log /tmp
exit
cd /tmp
ls -ltr
cat mptr299_20260710091351.log
cd ..
exit
id
/usr/libexec/openssh/sftp-server
/usr/libexec/openssh/sftp-server -u 007
ps -ef | grep -i sftp 
exit
cd /prod/race/oem/log
ls -l|more
ls -lt|more
catmptr299_20260710091351.log
cat mptr299_20260710091351.log
ls -lt|more
cd $HOME
pwd
which raceftp.ksh
which raceprofile.ksh
ls -la
cat .bash_profile
df -k
who
cd /prod/ftp_data
ls
ls -la
cd mdev
ls
ls -la
cd oem
ls
ls -la
ls -la | more
pwd
ls
df -k
cd /prod/race
ls
ls -la
cd oem
ls
ls -la
cd prm
ls
ls -la | more
       exit
ls -la
cat.bash_profile
cat .bash_profile
cp -p .bash_profile .bash_profile_bkup2
vi .bash_profile
exit
pwd
ls
view config
exit
clear
pwd
sftp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o GSSAPIAuthentication=no -o ConnectTimeout=10 -i/prod/race/oem/prm/.ssh/mitchell_oem_sftp_rsa ftp0099@204.44.187.3 <<< 'pwd'
exit
