; Debugging library using the UART interface


; Write a message into the console
; - @0 message
.macro DBMSG
    PRINTF	UART0_putc
    .db	CR, @0, CR, 0

.endmacro

; Write a message and the register values into the console
; - @0 message
; - @1 register (the binary value will be output)
.macro DBREG
    push a1
    push a0

    mov a0, @1
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, CR, 0

    pop a0
    pop a1
.endmacro

; Write a message and the register values into the console with formatting
; - @0 message
; - @1 format (FBIN, FHEX, FDEC, FCHAR, FSTR)
.macro DBREGF
    push a1
    push a0

    mov a0, @2
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, @1, a, CR, 0

    pop a0
    pop a1
.endmacro

; Write a message and the registers values into the console
; - @0 message
; - @1 register high
; - @2 register low
.macro DBREGS
    push a1
    push a0

    mov a1, @1
    mov a0, @2

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, CR, 0

    pop a0
    pop a1
.endmacro

; Write a message and the registers values into the console with formatting
; - @0 message
; - @1 format (FBIN, FHEX, FDEC, FCHAR, FSTR)
; - @2 register high
; - @3 register low
.macro DBREGSF
    push a1
    push a0

    mov a1, @2
    mov a0, @3

    PRINTF	UART0_putc
    .db	CR, @0, @1, a, CR, 0

    pop a0
    pop a1
.endmacro

; Write a message and the register IO values into the console
; - @0 message
; - @1 IO register (the binary value will be output)
.macro DBIO
    push a1
    push a0

    in a0, @1
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, CR, 0

    pop a0
    pop a1
.endmacro