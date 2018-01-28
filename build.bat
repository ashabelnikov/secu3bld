@echo off
rem  SECU-3  - An open source, free engine control unit
rem  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Kiev
rem 
rem Batch file for building of boot loader of SECU-3 project firmware
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 
rem Note: It requires avrasm2 AVR assembler from Atmel

set ASSEMBLER=avrasm2.exe
set HEXTOBIN=hextobin.exe
set USAGE=Supported options: M64,M644,M1284
set PLATFORM=Undefined

IF "%1" == "" (
echo Command line option required.
echo %USAGE%
exit 1
)

rem Check validity of command line option
IF %1 == M64 ( 
set PLATFORM=_PLATFORM_M64_
GOTO assemble
)

IF %1 == M644 ( 
set PLATFORM=_PLATFORM_M644_
GOTO assemble
)

IF %1 == M1284 ( 
set PLATFORM=_PLATFORM_M1284_
GOTO assemble
)

echo Invalid platform! 
echo %USAGE%
exit 1

:assemble
echo EXECUTING BATCH...
echo ---------------------------------------------

for %%X in (%ASSEMBLER%) do (set FOUND_ASM=%%~$PATH:X)
if not defined FOUND_ASM (
 echo ERROR: Can not find file "%ASSEMBLER%"
 goto error
)
%ASSEMBLER% -fI -D %PLATFORM% seculdr.asm -l seculdr.lst
IF ERRORLEVEL 1 GOTO error

for %%X in (%HEXTOBIN%) do (set FOUND_H2B=%%~$PATH:X)
if not defined FOUND_H2B (
 echo ERROR: Can not find file "%HEXTOBIN%"
 goto error
)
%HEXTOBIN% seculdr.hex seculdr.bin
IF ERRORLEVEL 1 GOTO error

echo ---------------------------------------------
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY!
exit 0

:error
echo ---------------------------------------------
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH.
exit 1
