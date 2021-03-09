;  SECU-3  - An open source, free engine control unit
;  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Kiev
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;  contacts:
;             http://secu-3.org
;             email: shabelnikov@secu-3.org

; file seculdr.asm
; author Alexey A. Shabelnikov

; Для работы загрузчика необходимо:
; размер загрузчика зависит от выбранной платформы (mega64, mega644, mega1284).
; BOOTRST = 0, BOOTSZ1 = 1, BOOTSZ0 = 0, JTAGEN = 1, WDTON = 1(mega64, mega644), M103C = 0(mega64).
; 1 - бит не запрограммирован
; Частота кварцевого резонатора: 16.000 мГц (mega64), 20.000 мГц (mega644, mega1284)

; - При запуске микроконтроллера управление передается загрузчику. Проверяется состояние
;   линии LDR_P_INIT порта C. Если на  ней низкий уровень, то производится продолжение работы
;   загрузчика. Иначе производится запуск приложения (Application section).
; - Загрузчик может быть активирован командой перехода из основной программы
; Адрес перехода - START_FROM_APP

;          Описание команд реализуемых через UART
;----------------------------------------------------------------------------------+
;   Программирование указанной страницы памяти программ                            |
;    !PNNdata<CS                     size      dir                                 |
;    !PNNNdata<CS                    size      dir            (ATMega1284)         |
;    P    - код команды               1        in                                  |
;    NN   - номер страницы            1        in                                  |
;    data - данные страницы          256max    in                                  |
;    CS   - контрольная сумма         1        out                                 |
;    перед посылкой блока данных необходимо подождать завершения стирания - 3-4 мс |
;----------------------------------------------------------------------------------+
;   Чтение указанной страницы памяти программ                                      |
;    !RNN<dataCS                     size      dir                                 |
;    !RNNN<dataCS                    size      dir            (ATMega1284)         |
;    R    - код команды               1        in                                  |
;    NN   - номер страницы            1        in                                  |
;    data - данные страницы          256max    out                                 |
;    CS   - контрольная сумма         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Выход из загрузчика и запуск основной программы                                |
;    !T<@                            size      dir                                 |
;    T    - код команды               1        in                                  |
;    @    - подтверждение вых.        1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Чтение содержимого EEPROM                                                      |
;    !J<dataCS                       size      dir                                 |
;    J    - код команды               1        in                                  |
;    data - данные EEPROM           4096max    out                                 |
;    CS   - контрольная сумма         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Запись содержимого EEPROM                                                      |
;    !Wdata<CS                       size      dir                                 |
;    W    - код команды               1        in                                  |
;    data - данные EEPROM           4096max    in                                  |
;    CS   - контрольная сумма         1        out                                 |
;    после посылки каждого байта необходимо подождать 10ms                         |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Write data to EEPROM (since v2.0)                                              |
;    !ZNNdata<CS                     size      dir                                 |
;    Z    - code of command           1        in                                  |
;    NN   - index of page             1        in                                  |
;    data - Data to be wr. to EEPROM  32       in                                  |
;    CS   - Checksum                  1        out                                 |
;    It is necessary to wait 100ms after sending data                              |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Read data from EEPROM (since v2.0)                                             |
;    !YNN<dataCS                     size      dir                                 |
;    Y    - code of command           1        in                                  |
;    NN   - index of page             1        in                                  |
;    data - Data to be rd.from EEPROM 32       out                                 |
;    CS   - контрольная сумма         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Передача информации о бутлоадере                                               |
;    !I<data                         size      dir                                 |
;    I    - код команды               1        in                                  |
;    data - передав. информация       24       out                                 |
;----------------------------------------------------------------------------------+
;
; Данные передаваемые загрузчиКУ  начинаются с символа !
; Данные передаваемые загрузчиКОМ начинаются с символа <
; size указан в байтах, в символах (передаваемых через UART) будет в 2 РАЗА больше
;
;   Eсли возникает ошибка, то загрузчик посылает в ответ <?
;

#if defined(_PLATFORM_M64_)
.INCLUDE "m64def.inc"
#message "ATMega64 platform used"
#define PLATFORM_CODE "64  "

#elif defined(_PLATFORM_M644_)
.INCLUDE "m644def.inc"
#message "ATMega644 platform used"
#define PLATFORM_CODE "644 "
.equ    SPMCR  = SPMCSR
.equ    WDTCR  = WDTCSR
.equ    EEWE   = EEPE
.equ    EEMWE  = EEMPE

#elif defined(_PLATFORM_M1284_)
.INCLUDE "m1284def.inc"
#message "ATMega1284 platform used"
#define PLATFORM_CODE "1284"
.equ    SPMCR  = SPMCSR
.equ    WDTCR  = WDTCSR
.equ    EEWE   = EEPE
.equ    EEMWE  = EEMPE

#else
 #error "Wrong platform identifier!"
#endif
 ;define UART registers, because mega64 has two UARTS and mega644 has different registers naming
.equ    UBRRL  = UBRR0L
.equ    UBRRH  = UBRR0H
.equ    RXEN   = RXEN0
.equ    TXEN   = TXEN0
.equ    UDR    = UDR0
.equ    RXC    = RXC0
.equ    UDRE   = UDRE0
.equ    UCSRA  = UCSR0A
.equ    UCSRB  = UCSR0B
.equ    U2X    = U2X0

.equ    LDR_P_INIT = 3                    ; line of PORT C used for manual starting boot loader
.equ    PAGESIZEB  = PAGESIZE*2           ; PAGESIZEB is page size in BYTES, not words
.equ    EEPAGESIZE = 32                   ; Size of block of data used to transfer data for R/W to EEPROM

;Here are some values for UBR for 16.000 mHz crystal
;
;       Speed    Value(U2X=0)  Value(U2X=1)
;       9600        0x67          0xCF
;       14400       0x44          0x8A
;       19200       0x33          0x67
;       28800       0x22          0x44
;       38400       0x19          0x33
;       57600       0x10          0x22
;       115200      0x08          0x10
;       250000      0x03          0x07
;Here are some values for UBR for 20.000 mHz crystal
;
;       Speed    Value(U2X=0)  Value(U2X=1)
;       9600        0x81          0x103
;       14400       0x56          0xAD
;       19200       0x40          0x81
;       28800       0x2A          0x56
;       38400       0x20          0x40
;       57600       0x15          0x2A
;       115200      0x0A          0x15
;       250000      0x04          0x09

#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
.equ    UBR        = 0x103                ; UART speed is 9600 baud 
#else
.equ    UBR        = 0xCF                 ; UART speed is 9600 baud
#endif

        .org  SECONDBOOTSTART             ; beginning of boot loader's code
        cli                               ; we do not use interrupts

        ldi   R16,0x0C                    ; connect internal pull-up resistor
        out   PORTC,R16
        clr   R0
        out   DDRC,R0                     ; make all lines of PORTC to be inputs

        ldi   R16,0x40                    ; approx. 6.4uS at 20MHz
pu_rise:
        dec   R16
        brne  pu_rise                     ; wait while pull-up voltage is rising

        sbic  PINC,LDR_P_INIT             ; if 0, then boot loader continue to work
        ; prevent 'Relative branch out of reach' compile error in some cases
        rjmp  StartProgram                ; else, start main firmware
START_FROM_APP:
        cli                               ; if we came from main firmware, then we have to disable interrupts
        ;initialize stack pointer
        ldi   R24,low(RAMEND)             ; SP = RAMEND
        ldi   R25,high(RAMEND)
        out   SPL,R24
        out   SPH,R25

        ;initialize UART

        ldi   R24,low(UBR)                ; set Baud rate (low byte)
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts  UBRRL,R24                    ; <--memory mapped
#else
        out  UBRRL,R24
#endif
        ldi   R24,high(UBR)               ; set Baud rate (high byte)
#if defined(_PLATFORM_M64_) || defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts   UBRRH,R24                   ; <--memory mapped
#else
        out   UBRRH,R24
        nop
#endif
        ldi   R24,(1<<RXEN)|(1<<TXEN)     ; Enable receiver & transmitter, 8-bit mode
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts   UCSRB,R24                   ; <--memory mapped
#else
        out   UCSRB,R24
#endif
        ldi   R24, (1<<U2X)               ; Use U2X to reduce baud error
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts   UCSRA, R24                  ; <--memory mapped
#else
        out   UCSRA, R24
#endif

        ;main loop of program  - waiting on commands

wait_cmd:    ;waiting new command
        rcall uartGet
        CPI   R16, '!'
        brne  wait_cmd
        ; receiving code of pending command
wait_cc:
        rcall uartGet
        CPI   R16,'!'
        breq  wait_cc                     ; do again, because marker of starting of packet has been received
        CPI   R16,'P'
        brne  CMD100
        ; Command 'P' programming specified page of perogram memory

#ifdef _PLATFORM_M1284_
        rcall recv_rampz                  ; Receive N and load it into RAMPZ register
#endif
        rcall recv_hex                    ; R16 <--- NN
        rcall page_num                    ; Z <-- number of page

        ;erase page
        ldi   R17, (1<<PGERS) | (1<<SPMEN)
        rcall Do_spm
        ;enable addressing of RWW section
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ; clear byte of check sum
        ;Write data from UART into page's buffer
        ldi   R24, low(PAGESIZEB)         ; initialize counter (number of bytes in page)

Wr_loop:  ;64(mega16, mega32), 128(mega64) iterations - two bytes per one iteration (one word)
        rcall recv_hex                    ; R16 <--- LO
        mov   R0,R16
        eor   R20,R16

        rcall recv_hex                    ; R16 <--- HI
        mov   R1,R16
        eor   R20,R16

        ldi   R17, (1<<SPMEN)
        rcall Do_spm
        adiw  ZH:ZL,2                     ; Z+=2, go to the next word on page
        subi  R24,  2                     ; R24-=2, decreased counter of words 
        brne  Wr_loop

        ; restoring pointer and carry out write of page
        subi  ZL, low(PAGESIZEB)          ; restore pointer
        sbci  ZH, high(PAGESIZEB)

        ldi   R17, (1<<PGWRT) | (1<<SPMEN)
        rcall Do_spm

        rcall sendAnswer

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd                    ; got to waiting on new command
       ;------------------------------------------------------------------------------
CMD100:
        CPI   R16,'R'
        brne  CMD200
        ; Command 'R'- read specified page of program memory

#ifdef _PLATFORM_M1284_
        rcall recv_rampz                  ; Receive N and load it into RAMPZ register
#endif
        rcall recv_hex
        rcall page_num                    ; Z <-- number of page

        rcall sendAnswer

        ;enable addressing of RWW section
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ; clear byte of check sum
        ; Read of page to UART
        ldi   R24, low(PAGESIZEB)         ; initializing counter
Rdloop:  ;64(mega16, mega32), 128(mega64) iteration

#if defined(_PLATFORM_M1284_)
        elpm  R16, Z+
#else
        lpm   R16, Z+
#endif
        eor   R20,R16
        rcall send_hex
        subi  R24, 1
        brne  Rdloop

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD200:
        CPI   R16,'J'
        brne  CMD300
        ; Command 'J' - read EEPROM

        rcall sendAnswer

        clr   R20                         ; clear byte of check sum
        clr   R26
        clr   R27
        ldi   R17,0x01                    ; read EEPROM
L23:
        rcall EepromRdWr
        eor   R20,R16
        rcall send_hex
        cpi   R27,high(EEPROMEND+1)       ; 512? 1024? 2048?
        BRNE  L23

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD300:
        CPI   R16,'Y'
        brne  CMD400
        ; command 'Y' - read EEPROM in block mode

        rcall recv_hex                    ; R16 <--- NN
        ldi   R24, EEPAGESIZE             ; load size of page, used as counter in below loop
        mul   R16, R24
        mov   R27, R1                     ; R27:R26 - address of page
        mov   R26, R0

        rcall sendAnswer

        clr   R20                         ; clear byte of check sum
        ldi   R17,0x01                    ; Read EEPROM
L24:
        rcall EepromRdWr
        eor   R20,R16
        rcall send_hex
        DEC   R24
        BRNE  L24

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD400:
        CPI   R16,'W'
        brne  CMD500
        ; Command 'W' - write EEPROM

        clr   R20                         ; clear byte of check sum
        clr   R26                         ; initialize pointer to EEPROM cells
        clr   R27                         ;
        ldi   R17,0x06                    ; write EEPROM
L25:
        rcall recv_hex
        out   EEDR,R16
        rcall EepromRdWr                  ; write
        eor   R20,R16
        cpi   R27,high(EEPROMEND+1)       ; 512? 1024? 2048?
        BRNE  L25

        rcall sendAnswer

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD500:
        CPI   R16,'Z'
        brne  CMD600
        ; Command 'Z' - write EEPROM in block mode

        rcall recv_hex                    ; R16 <--- NN
        ldi   R24, EEPAGESIZE             ; load size of page, used as counter in below loop
        mul   R16, R24
        mov   R27, R1                     ; R27:R26 - address of page
        mov   R26, R0

        ldi   ZL, low(1024)               ; start address in RAM for writing
        ldi   ZH, high(1024)
L26:
        rcall recv_hex
        ST    Z+, R16                     ;save byte to RAM
        subi  R24, 1
        BRNE  L26

        ldi   ZL, low(1024)               ; start address in RAM for reading
        ldi   ZH, high(1024)
        ldi   R24, EEPAGESIZE             ; load size of page, used as counter in below loop
        clr   R20                         ; clear byte of checksum
        ldi   R17,0x06                    ; запись EEPROM
L27:
        LD    R16, Z+
        out   EEDR,R16
        rcall EepromRdWr                  ; write
        eor   R20,R16
        subi  R24, 1
        BRNE  L27

        rcall sendAnswer

        ;transmit byte of check sum
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD600:
        CPI   R16,'T'
        brne  CMD700
        ; Command 'T' - exit from a boot loader (jump to $0000)

        rcall sendAnswer
        ldi   R16,'@'
        rcall uartSend                    ; sending confirmation

        ;wait for completion of sending and exit
w00:
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        lds   R16,UCSRA                   ; <--memory mapped
        sbrs  R16,UDRE
#else
        sbis  UCSRA,UDRE
#endif
        rjmp  w00

Return:
#ifdef _PLATFORM_M64_
        lds   R16,SPMCR                   ; <--memory mapped
#else
        in    R16,SPMCR
        nop                               ; to get the same code size
#endif
        sbrs  R16,RWWSB
        rjmp  do_strt_app                 ; Start the application program 
        ; re-enable the RWW section
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm
        rjmp  Return

        ;Enable watchdog timer and wait for system reset. Note: we rely that safety level
        ;is 0 (actual only for mega 64)
do_strt_app:
        ldi   R16, (1 << WDE)             ; 16 ms
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts   WDTCR, R16                  ; <--memory mapped
#else
        out   WDTCR, R16
#endif
wait_rst:
        rjmp  wait_rst

        ;------------------------------------------------------------------------------
CMD700:
        CPI   R16,'I'
        brne  CMD_NA
        ;Command 'I' - send information about boot loader

        rcall sendAnswer

#ifdef _PLATFORM_M1284_
        ldi   R24, 1
        OUT   RAMPZ, R24                  ; initialize RAMPZ register
#endif
        ldi ZL,low(2*info)                ; start address of the message
        ldi ZH,high(2*info)
isloop:

#if defined(_PLATFORM_M1284_)
        elpm  R16, Z+
#else
        lpm   R16, Z+                     ; string pointer (the Z-register)
#endif
        tst R16
        breq end_loop                     ; exit the character output loop if character was '\0'
        rcall uartSend                    ; send the read character via the UART
        rjmp isloop                       ; go to start of loop for next character
end_loop:
        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD_NA:
        ;Unknown command, send error code
        rcall sendAnswer
        ldi   R16,'?'
        rcall uartSend
        rjmp  wait_cmd

       ;-------------------------------------------------------------------------------


;sends <
sendAnswer:
        ldi   R16,'<'
        rcall uartSend
        ret


;reads one byte from UART and return it in the R16 register
uartGet:
        WDR
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        lds   R16,UCSRA                   ; <--memory mapped
        sbrs  R16,RXC
#else
        sbis  UCSRA,RXC                   ; wait for incoming data (until RXC==1)
#endif
        rjmp  uartGet
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        lds   R16,UDR                     ; <--memory mapped
#else
        in    R16,UDR                     ; return received data in R16
#endif
        ret

;writes one byte from R16 to UART
uartSend:
        WDR
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        lds   R17,UCSRA                   ; <--memory mapped
        sbrs  R17,UDRE
#else
        sbis  UCSRA,UDRE                  ; wait for empty transmit buffer (until UDRE==1)
#endif
        rjmp  uartSend
#if defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        sts   UDR,R16                     ; <--memory mapped
#else
        out   UDR,R16                     ; UDR = R16, start transmission
#endif
        ret


;Converts binary number from R16 into a Hex number in R17:R16
;In these registers Hex number is represented as two ASCII symbols
btoh:
        push  R18
        mov   R17,R16                     ; translate MS nubble of number to HEX
        SWAP  R17                         ; swap nibbles (move MS to LS)
        andi  R17,0x0F
        cpi   R17,0x0A
        BRLO  _b00                        ; if digit, then add 0x30, if letter, then add 0x37
        ldi   R18,7
        add   R17,R18
_b00:
        ldi   R18,0x30
        add   R17,R18
        andi  R16,0x0F                    ; translate LS nubble of number to HEX
        CPI   R16,0x0A
        BRLO  _b01
        ldi   R18,7
        add   R16,R18
_b01:
        ldi   R18,0x30
        add   R16,R18
        pop   R18
        ret


;converts Hex number from R17:R16 into a binary number in R16
;in R17:R16 Hex number is represented with two ASCII symbols
htob:
        push   R17
        cpi    R16,0x3A
        BRLO   _h00
        SUBI   R16,7                      ; if letter, then substract more
_h00:   ;digit
        subi   R16,0x30
        cpi    R17,0x3A
        BRLO   _h01
        SUBI   R17,7                      ; if letter, then substract more
_h01:   ;digit
        subi   R17,0x30
        SWAP   R17                        ; R17 contains MS nibble, swap ...
        OR     R16,R17
        pop    R17
        ret


;converts binary number from R16 to Hex number and send it via UART
send_hex:
        push  R16
        push  R17
        rcall btoh                        ; R17:R16 contain symbols of Hex-number
        push  R16                         ; save R16 because first we have to send high byte
        mov   R16,R17
        rcall uartSend
        pop   R16
        rcall uartSend                    ; send low byte of number
        pop   R17
        pop   R16
        ret

#ifdef _PLATFORM_M1284_
;Receive value of RAMPZ and set it
recv_rampz:
        push  R17
        rcall uartGet
        CPI   R16, '!'
        breq  new_cmd
        subi  R16, 0x30                 ;convert from hex to binary
        out   RAMPZ, R16
        pop   R17
        ret
#endif

;receives two symbols of Hex number and converts them to binary number
;result in R16
recv_hex:
        push  R17
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ; symbol of new command received
        mov   R17,R16
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ; symbol of new command received
        call  htob
        pop   R17
        ret
new_cmd:
        pop   R17
        pop   R16                         ; delete value of program counter from a stack
        pop   R16
        rjmp  wait_cc



;writes number of page from R16 to Z (into corresponding bits)
; Z register
; 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0
; x  x  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega16
; x  *  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega32    (64 words, 256 pages)
; *  *  *  *  *  *  *  *  0  0  0  0  0  0  0  0   mega64    (128 words, 256 pages)
; *  *  *  *  *  *  *  *  0  0  0  0  0  0  0  0   mega644   (128 words, 256 pages)
; *  *  *  *  *  *  *  *  0  0  0  0  0  0  0  0   mega1284  (128 words, 512 pages)
;
; x - doesn't matter
; * - number of page
; 0 - equal to zero
Page_num:
        mov   ZH,R16
#if defined(_PLATFORM_M64_) || defined(_PLATFORM_M644_) || defined(_PLATFORM_M1284_)
        nop
        clr   ZL
        nop
        nop
#else
        lsr   ZH
        clr   ZL
        bst   R16,0
        bld   ZL,7
#endif
        ret


; Executes specified programming operation
; R17 - current operation
Do_spm:
        ;check for completion of previous operation and wait if it was not finished yet
#ifdef _PLATFORM_M64_
        lds   R16,SPMCR                   ; <--memory mapped
#else
        in    R16,SPMCR
        nop                               ; to get the same code size
#endif
        WDR
        sbrc   R16, SPMEN
        rjmp   Do_spm
        ;check access to EEPROM and if it is open, then wait for completion of operation
Wait_ee:
        WDR
        sbic   EECR, EEWE
        rjmp   Wait_ee
        ;all is OK, apply SPM operation
#ifdef _PLATFORM_M64_
        sts   SPMCR, R17                  ; <--memory mapped
#else
        out   SPMCR, R17
        nop                               ; to get the same code size
#endif
        spm
        ret


;Reads or writes from/into EEPROM
;if R17 == 6 then Write, if R17 == 1 then Read
;R27:R26 - address
EepromRdWr:
        out EEARL,R26                     ; EEARL = address low
        out EEARH,R27                     ; EEARH = address high
        adiw R27:R26,1                    ; address++
        sbrc R17,1                        ; skip if R17 == 1 (read Eeprom)
        sbi EECR,EEMWE                    ; EEMWE = 1 (write Eeprom)
        out EECR,R17                      ; EECR = R17 (6 write, 1 read)
L90:
        WDR
        sbic EECR,EEWE                    ; wait until EEWE == 0
        rjmp L90
        in R16,EEDR                       ; R16 = EEDR
        ret

; Size must be 24 bytes |----------------------|
info:             .db  "SECU-3 BLDR v2.0.[03.21]",0,0 ;[mm.yy]
                  .db  "© 2007 A.Shabelnikov, http://secu-3.org",0

; [andreika]: fix 'Relative branch out of reach' compile error in some cases
StartProgram:
        jmp FLASHEND+1

        .org  FLASHEND-1
; MCU type information string, size must be 4 bytes
                  .db  PLATFORM_CODE
