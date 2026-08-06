@echo off
cd backup
if not exist regist01.dat goto label01
if not exist regist02.dat goto label02
if not exist regist03.dat goto label03
if not exist regist04.dat goto label04
if not exist regist05.dat goto label05
if not exist regist06.dat goto label06
if not exist regist07.dat goto label07
if not exist regist08.dat goto label08
if not exist regist09.dat goto label09
if not exist regist10.dat goto label10
:label01
if exist regist02.dat del regist02.dat
if exist clcl02.ini del clcl02.ini
copy ..\asmbr\regist.dat regist01.dat
copy ..\asmbr\clcl.ini clcl01.ini
goto fim
:label02
if exist regist03.dat del regist03.dat
if exist clcl03.ini del clcl03.ini
copy ..\asmbr\regist.dat regist02.dat
copy ..\asmbr\clcl.ini clcl02.ini
goto fim
:label03
if exist regist04.dat del regist04.dat
if exist clcl04.ini del clcl04.ini
copy ..\asmbr\regist.dat regist03.dat
copy ..\asmbr\clcl.ini clcl03.ini
goto fim
:label04
if exist regist05.dat del regist05.dat
if exist clcl05.ini del clcl05.ini
copy ..\asmbr\regist.dat regist04.dat
copy ..\asmbr\clcl.ini clcl04.ini
goto fim
:label05
if exist regist06.dat del regist06.dat
if exist clcl06.ini del clcl06.ini
copy ..\asmbr\regist.dat regist05.dat
copy ..\asmbr\clcl.ini clcl05.ini
goto fim
:label06
if exist regist07.dat del regist07.dat
if exist clcl07.ini del clcl07.ini
copy ..\asmbr\regist.dat regist06.dat
copy ..\asmbr\clcl.ini clcl06.ini
goto fim
:label07
if exist regist08.dat del regist08.dat
if exist clcl08.ini del clcl08.ini
copy ..\asmbr\regist.dat regist07.dat
copy ..\asmbr\clcl.ini clcl07.ini
goto fim
:label08
if exist regist09.dat del regist09.dat
if exist clcl09.ini del clcl09.ini
copy ..\asmbr\regist.dat regist08.dat
copy ..\asmbr\clcl.ini clcl08.ini
goto fim
:label09
if exist regist10.dat del regist10.dat
if exist clcl10.ini del clcl10.ini
copy ..\asmbr\regist.dat regist09.dat
copy ..\asmbr\clcl.ini clcl09.ini
goto fim
:label10
if exist regist01.dat del regist01.dat
if exist clcl01.ini del clcl01.ini
copy ..\asmbr\regist.dat regist10.dat
copy ..\asmbr\clcl.ini clcl10.ini
goto fim

:fim
