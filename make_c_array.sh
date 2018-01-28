#!/bin/sh
#  SECU-3  - An open source, free engine control unit
#  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Kiev
#
# Script for creating of C-array from boot loader's body under OS Linux.
# Created by Alexey A. Shabelnikov, Kiev 03 September 2013

ARRAYMAKER=bintoarray.exe
HEXTOBIN=hextobin.exe
USAGE="Supported options: M64,M644,M1284"
BL_ADDR=Undefined
BL_SIZE=Undefined


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

#Check validity of command line option and set corresponding parameters
if [ $1 = "M64" ]
then
 BL_ADDR=F800
 BL_SIZE=2048
elif [ $1 = "M644" ]
then
 BL_ADDR=F800
 BL_SIZE=2048
elif [ $1 = "M1284" ]
then
 BL_ADDR=1F800
 BL_SIZE=2048
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

#test if hextobin exists
wine $HEXTOBIN >> /dev/null
if [ $? -ne 1 ]
then
 echo "ERROR: Can not execute file "$HEXTOBIN
 PrintError
 exit 1
fi

#Run hextobin
wine $HEXTOBIN seculdr.hex seculdr.bin

#test if array maker exists
wine $ARRAYMAKER >> /dev/null    2>&1
if [ $? -ne 1 ]
then
 echo "ERROR: Can not execute file "$ARRAYMAKER
 PrintError
 exit 1
fi

wine $ARRAYMAKER seculdr.bin seculdr.c $BL_ADDR $BL_SIZE > arraymake_temp 2>&1
cat arraymake_temp
grep -q "ERROR: " arraymake_temp
if [ $? -eq 0 ]
then
 rm -rf arraymake_temp
 PrintError
 exit 1
fi
rm -rf arraymake_temp

echo
echo "---------------------------------------------"
echo "ALL OPERATIONS WERE COMPLETED SUCCESSFULLY!"
exit 0
