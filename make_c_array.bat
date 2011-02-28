@echo off
rem SECU-3 project
rem Batch file for creating of C-array from boot loader's body.
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 

set LOGFILE=make_c_array.log
set ARRAYMAKER=bintoarray.exe
set HEXTOBIN=hextobin.exe
set USAGE=Supported options: M16,M32,M64
set BL_ADDR=Undefined
set BL_SIZE=Undefined

IF "%1" == "" (
echo Command line option required.
echo %USAGE%
exit 1
)

rem Check validity of command line option and set corresponding parameters
IF %1 == M16 ( 
set BL_ADDR=3E00
set BL_SIZE=512
GOTO dowork
)

IF %1 == M32 ( 
set BL_ADDR=7C00
set BL_SIZE=1024
GOTO dowork
)

IF %1 == M64 ( 
set BL_ADDR=F800
set BL_SIZE=2048
GOTO dowork
)

echo Invalid platform! 
echo %USAGE%
exit 1

:dowork
echo See %LOGFILE% for detailed information.
IF EXIST %LOGFILE% del %LOGFILE%

echo EXECUTING BATCH... >> %LOGFILE%
echo --------------------------------------------- >> %LOGFILE%

IF NOT EXIST %HEXTOBIN% (
 echo ERROR: Can not find file "%HEXTOBIN%" >> %LOGFILE%
 goto error
)
%HEXTOBIN% seculdr.hex seculdr.bin  >> %LOGFILE%
IF ERRORLEVEL 1 GOTO error

IF NOT EXIST %ARRAYMAKER% (
 echo ERROR: Can not find file "%ARRAYMAKER%" >> %LOGFILE%
 goto error
)
%ARRAYMAKER% seculdr.bin seculdr.c %BL_ADDR% %BL_SIZE% >> %LOGFILE%
IF ERRORLEVEL 1 GOTO error

echo/ >> %LOGFILE%
echo --------------------------------------------- >> %LOGFILE%
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY! >> %LOGFILE%
exit 0

:error
echo --------------------------------------------- >> %LOGFILE%
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH. >> %LOGFILE%
exit 1
