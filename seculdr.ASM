; /****************************************************************
; *       SECU-3  - An open source, free engine control unit
; *    Designed by Alexey A. Shabelnikov. Ukraine, Gorlovka 2007.
; *       Microprocessors systems - design & programming.
; *    contacts:
; *              http://secu-3.narod.ru
; *              ICQ: 405-791-931
; ****************************************************************/



; Для работы загрузчика необходимо:
; размер загрузчика зависит от выбранной платформы (mega16, mega32, mega64).
; BOOTRST = 0, BOOTSZ1 = 1, BOOTSZ0 = 0, JTAGEN = 1, WDTON = 1(mega64), M103C = 0(mega64), кварц - 16.000 мГц 
; 1 - бит не запрограммирован

; - При запуске микроконтроллера управление передается загрузчику. Проверяется состояние 
;   линии LDR_P_INIT порта C. Если на  ней низкий уровень, то производится продолжение работы 
;   загрузчика. Иначе производится запуск приложения (Application section).  
; - Загрузчик может быть активирован командой перехода из основной программы
; Адрес перехода - START_FROM_APP

;          Описание команд реализуемых через UART
;----------------------------------------------------------------------------------+
;   Программирование указанной страницы памяти программ                            |
;    !PNNdata<CS                     size      dir                                 |
;    P    - код команды               1        in                                  |
;    NN   - номер страницы            1        in                                  |
;    data - данные страницы          256max    in                                  |
;    CS   - контрольная сумма         1        out                                 |
;    перед посылкой блока данных необходимо подождать завершения стирания - 3-4 мс |
;----------------------------------------------------------------------------------+
;   Чтение указанной страницы памяти программ                                      |
;    !RNN<dataCS                     size      dir                                 |
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
;    data - данные EEPROM           2048max    out                                 |
;    CS   - контрольная сумма         1        out                                 |
;----------------------------------------------------------------------------------+
;                                                                                  |
;   Запись запись содержимого EEPROM                                               |
;    !Wdata<CS                       size      dir                                 |
;    W    - код команды               1        in                                  |
;    data - данные EEPROM           2048max    in                                  |
;    CS   - контрольная сумма         1        out                                 |
;    после посылки каждого байта необходимо подождать 10ms                         |
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
;   Eсли возникает ошибка, то загрущчик посылает в ответ <?
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

#else
 #error "Wrong platform identifier!"
#endif

.equ    LDR_P_INIT = 3                    ;линия порта C для старта загрузчика при старте
.equ    PAGESIZEB  = PAGESIZE*2           ;PAGESIZEB is page size in BYTES, not words
.equ    UBR        = 0x67                 ;скорость UART-a - 9600 бод

        .org  SECONDBOOTSTART             ;начало кода загрузчика
        cli                               ;прерывания не используются

     	clr   R0
	out   DDRC,R0             	  ;делаем все линии порта C входами
	sbic  PINC,LDR_P_INIT	       	  ;если 0 то bootloader работает дальше
      	rjmp  FLASHEND+1	          ;иначе старт основной программы
START_FROM_APP:
        cli                               ;если мы пришли из программы то прерывания надо обязательно запретить
        ;инициализируем указатель стека
        ldi   R24,low(RAMEND)             ; SP = RAMEND
        ldi   R25,high(RAMEND)
        out   SPL,R24
        out   SPH,R25

        ;инициализируем UART
        ldi   R24,UBR                     ; set Baud rate
        out   UBRRL,R24
        ldi   R24,(1<<RXEN)|(1<<TXEN)     ; Enable receiver & transmitter, 8-bit mode
        out   UCSRB,R24

        ;основной цикл программы - ожидание команд

wait_cmd:    ;ожидание новой команды
        rcall uartGet
        CPI   R16, '!'
        brne  wait_cmd
        ; прием кода очередной команды
wait_cc:
        rcall uartGet
        CPI   R16,'P'
        brne  CMD100
        ; команда 'P' программирование указанной страницы памяти программ
        rcall recv_hex                    ;R16 <--- NN
        rcall page_num                    ;Z <-- номер страницы

        ;стираем страницу
        ldi   R17, (1<<PGERS) | (1<<SPMEN)
        rcall Do_spm
        ;разрешить адресацию области RWW
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ;очистили байт контрольной суммы
        ;Записываем данные из UART-a в буфер страницы
        ldi   R24, low(PAGESIZEB)         ;ининиализировали счетчик (кол-во байт в странице)

Wr_loop:  ;64(mega16, mega32), 128(mega64) итерации - за одну итерацию два байта (одно слово)
        rcall recv_hex                    ;R16 <--- LO
        mov   R0,R16
        eor   R20,R16

        rcall recv_hex                    ;R16 <--- HI
        mov   R1,R16
        eor   R20,R16

        ldi   R17, (1<<SPMEN)
        rcall Do_spm
        adiw  ZH:ZL,2                     ;Z+=2, переход к следующему слову в странице
        subi  R24,  2                     ;R24-=2, уменьшили счетчик слов 
        brne  Wr_loop

        ; восстанавливаем указатель и производим запись страницы
        subi  ZL, low(PAGESIZEB)          ;restore pointer
        sbci  ZH, high(PAGESIZEB)

        ldi   R17, (1<<PGWRT) | (1<<SPMEN)
        rcall Do_spm

        rcall sendAnswer

        ;передаем байт контрольной суммы
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd                    ; на ожидание новой команды
       ;------------------------------------------------------------------------------
CMD100:
        CPI   R16,'R'
        brne  CMD200
        ; команда 'R'- чтение указанной страницы памяти программ

        rcall recv_hex
        rcall page_num                    ;Z <-- номер страницы

        rcall sendAnswer

        ;разрешить адресацию области RWW
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm

        clr   R20                         ;очистили байт контрольной суммы
        ; Чтение страницы в UART
        ldi   R24, low(PAGESIZEB)         ;ининиализировали счетчик
Rdloop:  ;64(mega16, mega32), 128(mega64) итерации
        lpm   R16, Z+
        eor   R20,R16
        rcall send_hex
        subi  R24, 1
        brne  Rdloop

        ;передаем байт контрольной суммы
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD200:
        CPI   R16,'J'
        brne  CMD300
        ; команда 'J' - чтение EEPROM

        rcall sendAnswer
 
        clr   R20                         ;очистили байт контрольной суммы
        clr   R26
        clr   R27
        ldi   R17,0x01                    ; чтение EEPROM
L23:
        rcall EepromTalk
        eor   R20,R16              
        rcall send_hex
        cpi   R27,high(EEPROMEND+1)       ;512? 1024? 2048?
        BRNE  L23

        ;передаем байт контрольной суммы
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD300:
        CPI   R16,'W'
        brne  CMD400
        ; команда 'W' - запись EEPROM

        clr   R20                         ;очистили байт контрольной суммы
        clr   R26                         ;инициализировали указатель на ячейки EEPROM
        clr   R27                         ;
        ldi   R17,0x06                    ;запись EEPROM
L24:
        rcall recv_hex
        out   EEDR,R16
        rcall EepromTalk                  ;запись
        eor   R20,R16
        cpi   R27,high(EEPROMEND+1)       ;512? 1024? 2048?
        BRNE  L24

        rcall sendAnswer

        ;передаем байт контрольной суммы
        mov   R16,R20
        rcall send_hex

        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD400:
        CPI   R16,'T'
        brne  CMD500
        ; команда 'T' - выход из загрузчика (переход на $0000)

        rcall sendAnswer
        ldi   R16,'@'
        rcall uartSend                    ; посылка подтверждения

        ;ожидание завершения передачи, а затем выход
w00:
        sbis  UCSRA,UDRE
        rjmp  w00

Return:
#ifdef _PLATFORM_M64_
        lds   R16,SPMCR                   ;<--memory mapped
#else
        in    R16,SPMCR
        nop                               ;to get the same code size
#endif
        sbrs  R16,RWWSB
      	rjmp  do_strt_app	          ; Start the application program 
        ; re-enable the RWW section
        ldi   R17, (1<<RWWSRE) | (1<<SPMEN)
        rcall Do_spm
      	rjmp  Return

        ;Enable watchdog timer and wait for system reset. Note: we rely that safety level 
        ;is 0 (actual only for mega 64)
do_strt_app:
        ldi   R16, (1 << WDE)             ;16 ms
        out   WDTCR, R16        
wait_rst:
        rjmp  wait_rst                    

        ;------------------------------------------------------------------------------
CMD500:
        CPI   R16,'I'
        brne  CMD_NA
        ;команда 'I' - передача информации о бутлоадере

        rcall sendAnswer

	ldi ZL,low(2*info)                ; стартовый адрес сообщения
	ldi ZH,high(2*info)
isloop:
	lpm R16,Z+		          ; string pointer (the Z-register)
	tst R16
	breq end_loop	                  ; exit the character output loop if character was '\0'
	rcall uartSend 		          ; send the read character via the UART
	rjmp isloop                       ; go to start of loop for next character
end_loop:
        rjmp  wait_cmd
        ;------------------------------------------------------------------------------
CMD_NA:
        ;неизвесная команда, посылаем код ошибки
        rcall sendAnswer
        ldi   R16,'?'
        rcall uartSend
        rjmp  wait_cmd

       ;-------------------------------------------------------------------------------



;посылает <
sendAnswer:
        ldi   R16,'<'
        rcall uartSend
        ret


;читает один байт из UART и возвращает его в R16
uartGet:
        sbis  UCSRA,RXC                   ; wait for incoming data (until RXC==1)
        rjmp  uartGet
        in    R16,UDR                     ; return received data in R16
        ret

;записывает один байт из регистра R16 в UART
uartSend:
        sbis  UCSRA,UDRE                  ; wait for empty transmit buffer (until UDRE==1)
        rjmp  uartSend
        out   UDR,R16                     ; UDR = R16, start transmission
        ret


;переводит двойчное число из R16 в шестнадцатеричное число в R17:R16
;в этих регистрах шестнадцатеричное число представлено двумя ASCII символами
btoh:
        push  R18
        mov   R17,R16                     ;переводим старшую тетраду числа в HEX
        SWAP  R17                         ;делаем старшую тетраду младшей
        andi  R17,0x0F
        cpi   R17,0x0A
        BRLO  _b00                        ;если цифра то прибавляем 0x30, если буква то 0x37
        ldi   R18,7
        add   R17,R18
_b00:
        ldi   R18,0x30
        add   R17,R18
        andi  R16,0x0F                    ;переводим младшую тетраду числа в HEX
        CPI   R16,0x0A
        BRLO  _b01
        ldi   R18,7
        add   R16,R18
_b01:
        ldi   R18,0x30
        add   R16,R18
        pop   R18
        ret


;переводит шестнадцатеричное число из R17:R16 в двойчное в R16
;в регистрах R17:R16 шестнадцатеричное число представлено двумя ASCII символами
htob:
        push   R17
        cpi    R16,0x3A
        BRLO   _h00
        SUBI   R16,7                      ;если буква, то вычитаем еще
_h00:   ;цифра
        subi   R16,0x30
        cpi    R17,0x3A
        BRLO   _h01
        SUBI   R17,7                      ;если буква, то вычитаем еще
_h01:   ;цифра
        subi   R17,0x30
        SWAP   R17                        ;в R17 старшая тетрада - на место ее...
        OR     R16,R17
        pop    R17
        ret



;переводит двоичное число из R16 в шестнадцатеричное и передает его
send_hex:
        push  R16
        push  R17
        rcall btoh                        ;R17:R16 содержат символы HEX-числа
        push  R16                         ;сохраняем R16 так как сначала необходимо передать старший байт
        mov   R16,R17
        rcall uartSend
        pop   R16
        rcall uartSend                    ;передаем младший байт числа
        pop   R17
        pop   R16
        ret 


;принимает два символа шестнадцатеричного числа и переводит их в двоичное
;результат в R16
recv_hex:
        push  R17
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ;получен символ новой команды
        mov   R17,R16
        rcall uartGet
        CPI   R16,'!'
        breq  new_cmd                     ;получен символ новой команды
        call  htob
        pop   R17
        ret
new_cmd:
        pop   R17
        pop   R16                         ;удаляем из стека содержимое счетчика команд
        pop   R16
        rjmp  wait_cc



;записывает номер страницы из R16 в Z (в соответствующие биты)
; регистр Z
; 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0
; x  x  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega16
; x  *  *  *  *  *  *  *  *  0  0  0  0  0  0  0   mega32
; *  *  *  *  *  *  *  *  0  0  0  0  0  0  0  0   mega64
;
; x - не имеет значения
; * - номер страницы
; 0 - равны 0
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


; Осуществдение указанной операции программирования
; R17 - текущая операция
Do_spm:
        ;проверка зввершения предидущей SPM операции и ожидание если не завершена
#ifdef _PLATFORM_M64_
        lds   R16,SPMCR                   ;<--memory mapped
#else
        in    R16,SPMCR
        nop                               ;to get the same code size
#endif
        sbrc   R16, SPMEN
        rjmp   Do_spm
        ;проверяем доступ к EEPROM и если он открыт, то ждем завершения операции
Wait_ee:
        sbic   EECR, EEWE
        rjmp   Wait_ee
        ;все нормально - реализуем SPM операцию
#ifdef _PLATFORM_M64_
        sts   SPMCR, R17                  ;<--memory mapped
#else
        out   SPMCR, R17
        nop                               ;to get the same code size
#endif
        spm
        ret


;Читает или записывает EEPROM
;if R17 == 6 then Write, if R17 == 1 then Read
EepromTalk:
	out EEARL,R26 		          ; EEARL = address low
	out EEARH,R27 		          ; EEARH = address high
	adiw R27:R26,1 		          ; address++
	sbrc R17,1 		          ; skip if R17 == 1 (read Eeprom)
	sbi EECR,EEMWE 		          ; EEMWE = 1 (write Eeprom)
	out EECR,R17 		          ; EECR = R17 (6 write, 1 read)
L90:
	sbic EECR,EEWE 		          ; wait until EEWE == 0
	rjmp L90
	in R16,EEDR 		          ; R16 = EEDR
	ret

; размер должен быть 24 |----------------------|       
info:             .db  "Boot loader v1.2.[08.10]",0,0 ;[mm.yy]
