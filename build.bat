@echo off
rem Batch file for build boot loader of SECU-3 project firmware
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 
rem Note: It requires avrasm2 AVR assembler from Atmel

set LOGFILE=build.log
set ASSEMBLER=avrasm2.exe
set HEXTOBIN=hextobin.exe
set USAGE=Supported options: M16,M32,M64
set PLATFORM=Undefined

IF "%1" == "" (
echo Command line option required.
echo %USAGE%
exit 1
)

rem Check validity of command line option
IF %1 == M16 ( 
set PLATFORM=_PLATFORM_M16_
GOTO assemble
)

IF %1 == M32 ( 
set PLATFORM=_PLATFORM_M32_
GOTO assemble
)

IF %1 == M64 ( 
set PLATFORM=_PLATFORM_M64_
GOTO assemble
)

echo Invalid platform! 
echo %USAGE%
exit 1

:assemble
echo See %LOGFILE% for detailed information.
IF EXIST %LOGFILE% del %LOGFILE%

echo EXECUTING BATCH... >> %LOGFILE%
echo --------------------------------------------- >> %LOGFILE%

IF NOT EXIST %ASSEMBLER% (
 echo ERROR: Can not find file "%ASSEMBLER%" >> %LOGFILE%
 goto error
)
%ASSEMBLER% -fI -D %PLATFORM% seculdr.asm -l seculdr.lst >> %LOGFILE%
IF ERRORLEVEL 1 GOTO error

IF NOT EXIST %HEXTOBIN% (
 echo ERROR: Can not find file "%HEXTOBIN%" >> %LOGFILE%
 goto error
)
%HEXTOBIN% seculdr.hex seculdr.bin >> %LOGFILE%
IF ERRORLEVEL 1 GOTO error

echo --------------------------------------------- >> %LOGFILE%
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY! >> %LOGFILE%
exit 0

:error
echo --------------------------------------------- >> %LOGFILE%
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH. >> %LOGFILE%
exit 1
