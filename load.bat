@echo off
rem  SECU-3  - An open source, free engine control unit
rem  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Kiev
rem 
rem Batch file for loading of bootloader into the microcontroller.
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 

set PROGRAMMER=avreal32.exe
set USAGE=Supported options: M16,M32,M64,M644
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

IF %1 == M644 ( 
set MCU=+atmega644
GOTO dowork
)

echo Invalid platform! 
echo %USAGE%
exit 1

:dowork
echo EXECUTING BATCH...
echo ---------------------------------------------

for %%X in (%PROGRAMMER%) do (set FOUND_PGM=%%~$PATH:X)
if not defined FOUND_PGM (
 echo ERROR: Can not find file "%PROGRAMMER%"
 goto error
)
%PROGRAMMER% avreal32.exe -as -p1 %MCU% -o16MHZ -e -w seculdr.hex
IF ERRORLEVEL 1 GOTO error

echo ---------------------------------------------
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY!
exit 0

:error
echo ---------------------------------------------
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH.
exit 1
