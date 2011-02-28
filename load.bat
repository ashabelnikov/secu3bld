@echo off
rem SECU-3 project
rem Batch file for create C-array with boot loader body.
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 

set LOGFILE=load.log
set PROGRAMMER=avreal32.exe
set USAGE=Supported options: M16,M32,M64
set MCU=Undefined

IF "%1" == "" (
echo Command line option required.
echo %USAGE%
exit 1
)

rem Check validity of command line option and set corresponding parameters
IF %1 == M16 ( 
set MCU=+atmega16
GOTO dowork
)

IF %1 == M32 ( 
set MCU=+atmega32
GOTO dowork
)

IF %1 == M64 ( 
set MCU=+atmega64
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

IF NOT EXIST %PROGRAMMER% (
 echo ERROR: Can not find file "%PROGRAMMER%" >> %LOGFILE%
 goto error
)
%PROGRAMMER% avreal32.exe -as -p1 %MCU% -o16MHZ -e -w seculdr.hex >> %LOGFILE%
IF ERRORLEVEL 1 GOTO error

echo/ >> %LOGFILE%
echo --------------------------------------------- >> %LOGFILE%
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY! >> %LOGFILE%
exit 0

:error
echo --------------------------------------------- >> %LOGFILE%
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH. >> %LOGFILE%
exit 1
