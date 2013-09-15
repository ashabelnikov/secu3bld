
                     SECU-3 BOOT LOADER
                  Distributed under GPL license

           Designed by Alexey A. Shabelnikov 2007. Ukraine, Gorlovka.
           Microprocessor systems - design & programming.
           http://secu-3.org e-mail: shabelnikov@secu-3.org

  INTRODUCTION

  SECU-3 boot loader is used by SECU-3 and provides functionality for updating
of firmware. Visit main site http://secu-3.org for more information.

  PREREQUISITES

  Here is a list of tools you need to build code and load boot loader into device.

  1. Atmel AVR assembler - avrasm2.exe (Atmel AVR studio includes this one, so 
     you need to install it). Visit http://www.atmel.com for downloading of AVR
     Studio.

  2. hextobin.exe, bintoarray.exe. Download these utils using following link:
     http://subversion.assembla.com/svn/secu3doc/secu-3/utils/prgm_utils.zip

  3. AVReAl - for programming of Atmel AVR microcontrollers by ISP (avreal32.exe)
     or another tool (by your preference). Visit http://real.kiev.ua/avreal/

  Make sure that the PATH variable is set correctly and points to each from these
mentioned utils.

  DESCRIPTION

  seculdr.asm       source code of boot loader
  build.bat         build script (creates binary file)
  build.sh          Linux version of build.bat script
  load.bat          script for loading into device (using ISP)
  m16def.inc        --
  m32def.inc        device specific header files (used by build)
  m64def.inc        --
  m644def.inc       --
  license           contains GNU GPL license
  make_c_array.bat  script for creating of C-array from boot loader's binary
  make_c_array.sh   Linux version of make_c_array.bat script

 