;  SECU-3  - An open source, free engine control unit
;  Copyright (C) 2007 Alexey A. Shabelnikov. Ukraine, Gorlovka
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


; ��� ������ ���������� ����������:
; ������ ���������� ������� �� ��������� ��������� (mega16, mega32, mega64).
; BOOTRST = 0, BOOTSZ1 = 1, BOOTSZ0 = 0, JTAGEN = 1, WDTON = 1(mega64), M103C = 0(mega64), ����� - 16.000 ��� 
; 1 - ��� �� ����������������

; - ��� ������� ���������������� ���������� ���������� ����������. ����������� ��������� 
;   ����� LDR_P_INIT ����� C. ���� ��  ��� ������ �������, �� ������������ ����������� ������ 
;   ����������. ����� ������������ ������ ���������� (Application section).  
; - ��������� ����� ���� ����������� �������� �������� �� �������� ���������
; ����� �������� - START_FROM_APP

;          �������� ������ ����������� ����� UART
;----------------------------------------------------------------------------------+
;   ���������������� ��������� �������� ������ ��������                            |
;    !PNNdata<CS                     size      dir                                 |
;    P    - ��� �������               1        in                                  |
;    NN   - ����� ��������            1        in                                  |
;    data - ������ ��������          256max    in                                  |
;    CS   - ����������� �����         1        out                                 |
;    ����� �������� ����� ������ ���������� ��������� ���������� �������� - 3-4 �� |
;----------------------------------------------------------------------------------+
;   ������ ��������� �������� ������ ��������                                      |
;    !RNN<dataCS                     size      dir                                 |
;    R    - ��� �������               1        in                                  |
;    NN   - ����� ��������            1        in                                  |
;    data - ������ ��������          256max    out                                 |
;    CS   - ����������� �����         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   ����� �� ���������� � ������ �������� ���������                                |
;    !T<@                            size      dir                                 |
;    T    - ��� �������               1        in                                  |
;    @    - ������������� ���.        1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   ������ ����������� EEPROM                                                      |
;    !J<dataCS                       size      dir                                 |
;    J    - ��� �������               1        in                                  |
;    data - ������ EEPROM           2048max    out                                 |
;    CS   - ����������� �����         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   ������ ������ ����������� EEPROM                                               |
;    !Wdata<CS                       size      dir                                 |
;    W    - ��� �������               1        in                                  |
;    data - ������ EEPROM           2048max    in                                  |
;    CS   - ����������� �����         1        out                                 |
;    ����� ������� ������� ����� ���������� ��������� 10ms                         |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   �������� ���������� � ����������                                               |
;    !I<data                         size      dir                                 |
;    I    - ��� �������               1        in                                  |
;    data - �������. ����������       24       out                                 |
;----------------------------------------------------------------------------------+
;
; ������ ������������ ����������  ���������� � ������� !
; ������ ������������ ����������� ���������� � ������� <
; size ������ � ������, � �������� (������������ ����� UART) ����� � 2 ���� ������
;
;   E��� ��������� ������, �� ��������� �������� � ����� <?
;

#ifdef _PLATFORM_M16_
.INCLUDE "m16def.inc"
#message "ATMega16 platform used"
#elif _PLATFORM_M32_
.INCLUDE "m32def.inc"
#message "ATMega32 platform used"
#elif _PLATFORM_M64_
.INCLUDE "m64def.inc"
#message "ATMega64 platform used"
 ;define UART registers, because mega 64 has two UARTS
.equ    UBRRL = UBRR0L
.equ    RXEN  = RXEN0
.equ    TXEN  = TXEN0
.equ    UDR   = UDR0
.equ    RXC   = RXC0
.equ    UDRE  = UDRE0
.equ    UCSRA = UCSR0A
.equ    UCSRB = UCSR0B
.equ    U2X   = U2X0

#else
 #error "Wrong platform identifier!"
#endif

.equ    LDR_P_INIT = 3                    ; ����� ����� C ��� ������ ���������� ��� ������
.equ    PAGESIZEB  = PAGESIZE*2           ; PAGESIZEB is page size in BYTES, not words

;Here are some values for UBR for 16.000 mHz crystal
;
;       Speed    Value(U2X=0)  Value(U2X=1)
;       9600        0x67          0xCF
;       14400       0x44          0x8A
;       19200       0x33          0x67
;       28800       0x22          0x44
;       38400       0x19          0x33
;       57600       0x10          0x22

.equ    UBR        = 0xCF                 ; UART speed 9600 baud (�������� UART-a)

        .org  SECONDBOOTSTART             ; ������ ���� ����������
        cli                               ; ���������� �� ������������

        clr   R0
        out   DDRC,R0                     ; ������ ��� ����� ����� C �������
        sbic  PINC,LDR_P_INIT             ; ���� 0 �� bootloader �������� ������
        rjmp  FLASHEND+1                  ; ����� ����� �������� ���������
START_FROM_APP:
        cli                               ; ���� �� ������ �� ��������� �� ���������� ���� ����������� ���������
        ;�������������� ��������� �����
        ldi   R24,low(RAMEND)             ; SP = RAMEND
        ldi   R25,high(RAMEND)
        out   SPL,R24
        out   SPH,R25

        ;�������������� UART
        ldi   R24,UBR                     ; set Baud rate
        out   UBRRL,R24
        ldi   R24,(1<<RXEN)|(1<<TXEN)     ; Enable receiver & transmitter, 8-bit mode
        out   UCSRB,R24
        ldi   R24, (1<<U2X)               ; Use U2X to reduce baud error
        out   UCSRA, R24

        ;�������� ���� ��������� - �������� ������

wait_cmd:    ;�������� ����� �������
        rcall uartGet
        CPI   R16, '!'
        brne  wait_cmd
        ; ����� ���� ��������� �������
wait_cc:
        rcall uartGet
        CPI   R16,'P'
        brne  CMD100
        ; ������� 'P' ���������������� ��������� �������� ������ ��������
        rcall recv_hex                    ; R16 <--- NN
        rcall page_num                    ; Z <-- ����� ��������

        ;������� ��������
        ldi   R17, (1<<PGERS) | (1<<SPMEN)
        rcall Do_spm
        ;��������� ��������� ������� RWW
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ; �������� ���� ����������� �����
        ;���������� ������ �� UART-a � ����� ��������
        ldi   R24, low(PAGESIZEB)         ; ���������������� ������� (���-�� ���� � ��������)

Wr_loop:  ;64(mega16, mega32), 128(mega64) �������� - �� ���� �������� ��� ����� (���� �����)
        rcall recv_hex                    ; R16 <--- LO
        mov   R0,R16
        eor   R20,R16

        rcall recv_hex                    ; R16 <--- HI
        mov   R1,R16
        eor   R20,R16

        ldi   R17, (1<<SPMEN)
        rcall Do_spm
        adiw  ZH:ZL,2                     ; Z+=2, ������� � ���������� ����� � ��������
        subi  R24,  2                     ; R24-=2, ��������� ������� ���� 
        brne  Wr_loop

        ; ��������������� ��������� � ���������� ������ ��������
        subi  ZL, low(PAGESIZEB)          ; restore pointer
        sbci  ZH, high(PAGESIZEB)

        ldi   R17, (1<<PGWRT) | (1<<SPMEN)
        rcall Do_spm

        rcall sendAnswer

        ;�������� ���� ����������� �����
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd                    ; �� �������� ����� �������
       ;------------------------------------------------------------------------------
CMD100:
        CPI   R16,'R'
        brne  CMD200
        ; ������� 'R'- ������ ��������� �������� ������ ��������

        rcall recv_hex
        rcall page_num                    ; Z <-- ����� ��������

        rcall sendAnswer

        ;��������� ��������� ������� RWW
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ; �������� ���� ����������� �����
        ; ������ �������� � UART
        ldi   R24, low(PAGESIZEB)         ; ���������������� �������
Rdloop:  ;64(mega16, mega32), 128(mega64) ��������
        lpm   R16, Z+
        eor   R20,R16
        rcall send_hex
        subi  R24, 1
        brne  Rdloop

        ;�������� ���� ����������� �����
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD200:
        CPI   R16,'J'
        brne  CMD300
        ; ������� 'J' - ������ EEPROM

        rcall sendAnswer

        clr   R20                         ; �������� ���� ����������� �����
        clr   R26
        clr   R27
        ldi   R17,0x01                    ; ������ EEPROM
L23:
        rcall EepromTalk
        eor   R20,R16
        rcall send_hex
        cpi   R27,high(EEPROMEND+1)       ; 512? 1024? 2048?
        BRNE  L23

        ;�������� ���� ����������� �����
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD300:
        CPI   R16,'W'
        brne  CMD400
        ; ������� 'W' - ������ EEPROM

        clr   R20                         ; �������� ���� ����������� �����
        clr   R26                         ; ���������������� ��������� �� ������ EEPROM
        clr   R27                         ;
        ldi   R17,0x06                    ; ������ EEPROM
L24:
        rcall recv_hex
        out   EEDR,R16
        rcall EepromTalk                  ; ������
        eor   R20,R16
        cpi   R27,high(EEPROMEND+1)       ; 512? 1024? 2048?
        BRNE  L24

        rcall sendAnswer

        ;�������� ���� ����������� �����
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD400:
        CPI   R16,'T'
        brne  CMD500
        ; ������� 'T' - ����� �� ���������� (������� �� $0000)

        rcall sendAnswer
        ldi   R16,'@'
        rcall uartSend                    ; ������� �������������

        ;�������� ���������� ��������, � ����� �����
w00:
        sbis  UCSRA,UDRE
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
        out   WDTCR, R16
wait_rst:
        rjmp  wait_rst

        ;------------------------------------------------------------------------------
CMD500:
        CPI   R16,'I'
        brne  CMD_NA
        ;������� 'I' - �������� ���������� � ����������

        rcall sendAnswer

        ldi ZL,low(2*info)                ; ��������� ����� ���������
        ldi ZH,high(2*info)
isloop:
        lpm R16,Z+                        ; string pointer (the Z-register)
        tst R16
        breq end_loop                     ; exit the character output loop if character was '\0'
        rcall uartSend                    ; send the read character via the UART
        rjmp isloop                       ; go to start of loop for next character
end_loop:
        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD_NA:
        ;���������� �������, �������� ��� ������
        rcall sendAnswer
        ldi   R16,'?'
        rcall uartSend
        rjmp  wait_cmd

       ;-------------------------------------------------------------------------------


;�������� <
sendAnswer:
        ldi   R16,'<'
        rcall uartSend
        ret


;������ ���� ���� �� UART � ���������� ��� � R16
uartGet:
        sbis  UCSRA,RXC                   ; wait for incoming data (until RXC==1)
        rjmp  uartGet
        in    R16,UDR                     ; return received data in R16
        ret

;���������� ���� ���� �� �������� R16 � UART
uartSend:
        sbis  UCSRA,UDRE                  ; wait for empty transmit buffer (until UDRE==1)
        rjmp  uartSend
        out   UDR,R16                     ; UDR = R16, start transmission
        ret


;��������� �������� ����� �� R16 � ����������������� ����� � R17:R16
;� ���� ��������� ����������������� ����� ������������ ����� ASCII ���������
btoh:
        push  R18
        mov   R17,R16                     ; ��������� ������� ������� ����� � HEX
        SWAP  R17                         ; ������ ������� ������� �������
        andi  R17,0x0F
        cpi   R17,0x0A
        BRLO  _b00                        ; ���� ����� �� ���������� 0x30, ���� ����� �� 0x37
        ldi   R18,7
        add   R17,R18
_b00:
        ldi   R18,0x30
        add   R17,R18
        andi  R16,0x0F                    ; ��������� ������� ������� ����� � HEX
        CPI   R16,0x0A
        BRLO  _b01
        ldi   R18,7
        add   R16,R18
_b01:
        ldi   R18,0x30
        add   R16,R18
        pop   R18
        ret


;��������� ����������������� ����� �� R17:R16 � �������� � R16
;� ��������� R17:R16 ����������������� ����� ������������ ����� ASCII ���������
htob:
        push   R17
        cpi    R16,0x3A
        BRLO   _h00
        SUBI   R16,7                      ; ���� �����, �� �������� ���
_h00:   ;�����
        subi   R16,0x30
        cpi    R17,0x3A
        BRLO   _h01
        SUBI   R17,7                      ; ���� �����, �� �������� ���
_h01:   ;�����
        subi   R17,0x30
        SWAP   R17                        ; � R17 ������� ������� - �� ����� ��...
        OR     R16,R17
        pop    R17
        ret



;��������� �������� ����� �� R16 � ����������������� � �������� ���
send_hex:
        push  R16
        push  R17
        rcall btoh                        ; R17:R16 �������� ������� HEX-�����
        push  R16                         ; ��������� R16 ��� ��� ������� ���������� �������� ������� ����
        mov   R16,R17
        rcall uartSend
        pop   R16
        rcall uartSend                    ; �������� ������� ���� �����
        pop   R17
        pop   R16
        ret 


;��������� ��� ������� ������������������ ����� � ��������� �� � ��������
;��������� � R16
recv_hex:
        push  R17
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ; ������� ������ ����� �������
        mov   R17,R16
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ; ������� ������ ����� �������
        call  htob
        pop   R17
        ret
new_cmd:
        pop   R17
        pop   R16                         ; ������� �� ����� ���������� �������� ������
        pop   R16
        rjmp  wait_cc



;���������� ����� �������� �� R16 � Z (� ��������������� ����)
; ������� Z
; 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0
; x  x  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega16
; x  *  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega32
; *  *  *  *  *  *  *  *  0  0  0  0  0  0  0  0   mega64
;
; x - �� ����� ��������
; * - ����� ��������
; 0 - ����� 0
Page_num:
        mov   ZH,R16
#ifdef _PLATFORM_M64_
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


; ������������� ��������� �������� ����������������
; R17 - ������� ��������
Do_spm:
        ;�������� ���������� ���������� SPM �������� � �������� ���� �� ���������
#ifdef _PLATFORM_M64_
        lds   R16,SPMCR                   ; <--memory mapped
#else
        in    R16,SPMCR
        nop                               ; to get the same code size
#endif
        sbrc   R16, SPMEN
        rjmp   Do_spm
        ;��������� ������ � EEPROM � ���� �� ������, �� ���� ���������� ��������
Wait_ee:
        sbic   EECR, EEWE
        rjmp   Wait_ee
        ;��� ��������� - ��������� SPM ��������
#ifdef _PLATFORM_M64_
        sts   SPMCR, R17                  ; <--memory mapped
#else
        out   SPMCR, R17
        nop                               ; to get the same code size
#endif
        spm
        ret


;������ ��� ���������� EEPROM
;if R17 == 6 then Write, if R17 == 1 then Read
EepromTalk:
        out EEARL,R26                     ; EEARL = address low
        out EEARH,R27                     ; EEARH = address high
        adiw R27:R26,1                    ; address++
        sbrc R17,1                        ; skip if R17 == 1 (read Eeprom)
        sbi EECR,EEMWE                    ; EEMWE = 1 (write Eeprom)
        out EECR,R17                      ; EECR = R17 (6 write, 1 read)
L90:
        sbic EECR,EEWE                    ; wait until EEWE == 0
        rjmp L90
        in R16,EEDR                       ; R16 = EEDR
        ret

; ������ ������ ���� 24 |----------------------|
info:             .db  "Boot loader v1.3.[11.11]",0,0 ;[mm.yy]