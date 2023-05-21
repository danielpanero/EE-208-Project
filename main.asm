.include "m128def.inc"
.include "macros.asm"
.include "definitions.asm"

.org 0
    rjmp reset


.org ADCCaddr
	jmp	analog_service_routine


.include "lcd.asm"	
.include "printf.asm"
.include "uart.asm"
.include "debug.asm"

.include "sound.asm"
.include "analog.asm"

reset:
    LDSP RAMEND ; Load stack pointer SP
    sei ; Activate interrupts

    ; Library initializations: 
    rcall LCD_init ; Init lcd.asm library
    rcall UART0_init ; Init uart.asm
    rcall sound_init ; Init sound.asm library
    rcall analog_init ; Init analog.asm library

    OUTI DDRB, 1 ; Configure portD as input
    rjmp main


.def note_index = r21

main:   
    rcall analog_loop

    clr note_index 
    rcall loop_normalize_note_index

    clr b1
    mov b0, note_index

    ; Going through the notes_tbl: note_index = 0 --> lowest note, note_index = 23 --> highest note:
    LDIZ 2*(notes_tbl_la)
    ADDZ note_index

    lpm

    mov period, r0
    ;DBREGF "The note index: ", FDEC|FSIGN, note_index
    ;DBREGF "The period: ", FDEC, period

    _LDI durationh, high(11000)
    _LDI durationl, low(11000)

    rcall sound

    rjmp main

loop_normalize_note_index:
    inc note_index

    ;DBREGSF "Analog: ", FDEC2, analogh, analogl
    SUBI2 analogh, analogl, analog_max_value / (notes_tbl_index_max+2)  ; We choosed to place a note every 40 dec
    ;DBSREG "SREG: "
    JC0 loop_normalize_note_index ; If analogh:analog_loop > 40, we can still make an higher note

    dec note_index

    cpi note_index, notes_tbl_index_min ; note_index must be >= 0
    brsh PC+2 
    ldi note_index, notes_tbl_index_min

    cpi note_index, notes_tbl_index_max + 1 ; note_index must be <= 23
    brlo PC+2
    ldi note_index, notes_tbl_index_max

    ;DBREGF "Final note found was: ", FDEC, note_index
    ret
