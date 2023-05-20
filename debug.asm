; Debugging library using the UART interface

.macro DBMSG
    PRINTF	UART0_putc
    .db	CR, @0, " " CR, 0

.endmacro

.macro DBREG
    mov a0, @1
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, " ", FBIN, a, CR, 0

.endmacro

.macro DBREGS
    mov a1, @1
    mov a0, @2

    PRINTF	UART0_putc
    .db	CR, @0, " ", FBIN, a, CR, 0

.endmacro