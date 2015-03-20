#!/bin/sh
#  SECU-3  - An open source, free engine control unit
#  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Kiev
#
#Batch file for building of boot loader of SECU-3 project firmware under Linux OS
#Created by Alexey A. Shabelnikov, Kiev 29 August 2013.
#Note: It requires avrasm2 AVR assembler from Atmel and wine

ASSEMBLER=avrasm2.exe
HEXTOBIN=hextobin.exe
USAGE="Supported options: M16,M32,M64,M644"
PLATFORM=Undefined

if [ $# -eq 0 ]
then
 echo "Command line option required."
 echo $USAGE
 exit 1
elif [ $# -ne 1 ]
then
 echo "Wring number of command line options."
 exit 1
fi

# Check validity of command line option and set corresponding parameters
if [ $1 = "M16" ]
then
 PLATFORM=_PLATFORM_M16_
elif [ $1 = "M32" ]
then
 PLATFORM=_PLATFORM_M32_
elif [ $1 = "M64" ]
then
 PLATFORM=_PLATFORM_M64_
elif [ $1 = "M644" ]
then
 PLATFORM=_PLATFORM_M644_
else
 echo "Invalid platform!"
 echo $USAGE
 exit 1
fi

echo "EXECUTING BATCH..."
echo "---------------------------------------------"

PrintError() {
echo "--------------------------------------------"
echo "WARNING! THERE ARE SOME ERRORS IN EXECUTING BATCH."
}

#test if assembler exists
wine $ASSEMBLER >> /dev/null    2>&1
if [ $? -ne 1 ]
then
 echo "ERROR: Can not execute file "$ASSEMBLER
 PrintError
 exit 1
fi

#test if hextobin exists
wine $HEXTOBIN >> /dev/null
if [ $? -ne 1 ]
then
 echo "ERROR: Can not execute file "$HEXTOBIN
 PrintError
 exit 1
fi

#Run assembler
wine $ASSEMBLER -fI -D $PLATFORM seculdr.asm -l seculdr.lst > build_temp 2>&1
cat build_temp
grep -q "): error:" build_temp
if [ $? -eq 0 ]
then
 rm -rf build_temp
 PrintError
 exit 1
fi
rm -rf build_temp


#Run hextobin
wine $HEXTOBIN seculdr.hex seculdr.bin

echo "---------------------------------------------"
echo "ALL OPERATIONS WERE COMPLETED SUCCESSFULLY!"
exit 0

