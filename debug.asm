; file:	debug.asm   target ATmega128L-4MHz-STK300
; Debugging library using the UART interface
; Copyright 2023: Daniel Panero (342800), Yasmina Jemili (310507)

.define DEBUG 1

.if DEBUG == 1
; Write a message into the console
; - @0 message
.macro DBMSG
    in _sreg, SREG
    push _sreg

    PRINTF	UART0_putc
    .db	CR, @0, 0

    pop _sreg
    out SREG, _sreg
.endmacro

; Write a message and SREG into the console
; - @0 message
.macro DBSREG
    push a1
    push a0

    in a0, SREG
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, 0

    out SREG, a0
    pop a0
    pop a1

.endmacro

; Write a message and the register values into the console
; - @0 message
; - @1 register (the binary value will be output)
.macro DBREG
    push a1
    push a0

    in _sreg, SREG
    push _sreg

    mov a0, @1
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, 0

    pop _sreg
    out SREG, _sreg

    pop a0
    pop a1
.endmacro

; Write a message and the register values into the console with formatting
; - @0 message
; - @1 format (FBIN, FHEX, FDEC, FCHAR, FSTR)
.macro DBREGF
    push a1
    push a0

    in _sreg, SREG
    push _sreg

    mov a0, @2
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, @1, a, 0

    pop _sreg
    out SREG, _sreg

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

    in _sreg, SREG
    push _sreg

    mov a1, @1
    mov a0, @2

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, 0

    pop _sreg
    out SREG, _sreg

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

    in _sreg, SREG
    push _sreg

    mov a1, @2
    mov a0, @3

    PRINTF	UART0_putc
    .db	CR, @0, @1, a, 0

    pop _sreg
    out SREG, _sreg

    pop a0
    pop a1
.endmacro

; Write a message and the register IO values into the console
; - @0 message
; - @1 IO register (the binary value will be output)
.macro DBIO
    push a1
    push a0

    in _sreg, SREG
    push _sreg

    in a0, @1
    clr a1

    PRINTF	UART0_putc
    .db	CR, @0, FBIN, a, 0

    pop _sreg
    out SREG, _sreg

    pop a0
    pop a1
.endmacro

.else

.macro DBMSG 
.endmacro
.macro DBSREG
.endmacro
.macro DBREG 
.endmacro
.macro DBREGF
.endmacro
.macro DBREGS 
.endmacro
.macro DBREGSF 
.endmacro
.macro DBIO 
.endmacro

.endif
