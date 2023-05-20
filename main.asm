.include "m128def.inc"
.include "macros.asm"
.include "definitions.asm"

.org 0
    rjmp reset

.include "lcd.asm"	
.include "printf.asm"
.include "uart.asm"
.include "sound.asm"
.include "debug.asm"

reset:
    LDSP RAMEND ; Load stack pointer SP
    sei ; Activate interrupts

    ; Library initializations: 
    rcall LCD_init ; Init lcd.asm library
    rcall UART0_init ; Init uart.asm
    rcall sound_init ; Init sound.asm library
    OUTI DDRB, 0 ; configure portD as input
    rjmp main


main:
    LDI2 durationh, durationl, 11000

    SP1 PIND, 0
    LDI2 periodh, periodl, do

    SP1 PIND, 1
    LDI2 periodh, periodl, re

    SP1 PIND, 2
    LDI2 periodh, periodl, mi

    SP1 PIND, 3
    LDI2 periodh, periodl, fa

    SP1 PIND, 4
    LDI2 periodh, periodl, so

    SP1 PIND, 5
    LDI2 periodh, periodl, la

    SP1 PIND, 6
    LDI2 periodh, periodl, si

    rcall sound

    rjmp main

