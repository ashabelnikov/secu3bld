@echo off
rem SECU-3 project
rem Batch file for creating of C-array from boot loader's body.
rem Created by Alexey A. Shabelnikov, Kiev 28 August 2010. 

set ARRAYMAKER=bintoarray.exe
set HEXTOBIN=hextobin.exe
set USAGE=Supported options: M16,M32,M64,M644
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

IF %1 == M644 ( 
set BL_ADDR=F800
set BL_SIZE=2048
GOTO dowork
)

echo Invalid platform! 
echo %USAGE%
exit 1

:dowork
echo EXECUTING BATCH...
echo ---------------------------------------------


for %%X in (%HEXTOBIN%) do (set FOUND_H2B=%%~$PATH:X)
if not defined FOUND_H2B (
 echo ERROR: Can not find file "%HEXTOBIN%"
 goto error
)
%HEXTOBIN% seculdr.hex seculdr.bin
IF ERRORLEVEL 1 GOTO error


for %%X in (%ARRAYMAKER%) do (set FOUND_AM=%%~$PATH:X)
if not defined FOUND_AM (
 echo ERROR: Can not find file "%ARRAYMAKER%"
 goto error
)
%ARRAYMAKER% seculdr.bin seculdr.c %BL_ADDR% %BL_SIZE%
IF ERRORLEVEL 1 GOTO error

echo/
echo ---------------------------------------------
echo ALL OPERATIONS WERE COMPLETED SUCCESSFULLY!
exit 0

:error
echo ---------------------------------------------
echo WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH.
exit 1
