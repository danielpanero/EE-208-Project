
.def event = r18

.equ ARROW_UP = 0x00
.equ ARROW_DOWN = 0x01

.equ ENTER = 0x0A

.equ YES = 0x0B
.equ NO = 0x0C

.equ MAX_NUMBER_RANGE = 0x09

; in @0 register, @1 lower limit, @2 upper limit, @3 address for updating the screen while waiting
.macro CIN_CYCLIC
    push event
cin_cyclic_loop_%:
    CB_POP events_buffer, events_buffer_length, event
    brts @3 ; Branch if empty (T=1)

cin_cyclic_enter_%
    cpi event, ENTER
    breq cin_cyclic_end_%

cin_cyclic_arrow_up_%:   
    cpi event, ARROW_UP
    brne cin_cyclic_arrow_down_%
    INC_CYC @0, @1, @2
cin_cyclic_arrow_down_%:   
    cpi event, ARROW_DOWN
    brne cin_cyclic_loop_%
    DEC_CYC @0, @1, @2

    rjmp cin_cyclic_loop_%

cin_cyclic_end_%:
    pop event
.endmacro

; in @0 register, @1 address for updating the screen while waiting
.macro CIN_NUM
    PUSH3 event, a0, b0, c0
cin_num_loop_%:
    CB_POP events_buffer, events_buffer_length, event
    brts @3 ; Branch if empty (T=1)

cin_num_enter_%
    cpi event, ENTER
    breq cin_num_end_%

cin_num_%:
    ; Check if it is a number
    cpi event, MAX_NUMBER_RANGE + 1
    brsh cin_num_end_%

    ; Multiply the number before by ten
    mov a0, @0
    ldi b0, 10
    
    rcall mul11

    ; Add the event number
    mov @0, c0
    add @0, event

    ; Checking for overflow
    brcc PC+2
    mov @0, event

    rjmp cin_num_loop_%


cin_num_end_%:
    POP3 event, a0, b0, c0
.endmacro

; in @0 address for updating the screen while waiting
.macro CIN_YES_NO
    push event
cin_yes_no_loop_%:
    CB_POP events_buffer, events_buffer_length, event
    brts @0 ; Branch if empty (T=1)

cin_yes_%:   
    cpi event, YES
    brne cin_no_%
    set
    rjmp cin_yes_no_end_
cin_no_%:   
    cpi event, NO
    brne cin_yes_no_loop_%
    clt
    rjmp cin_yes_no_end_
cin_yes_no_end_%:
    pop event
.endmacro

; in @0 key to wait, @1 address for updating the screen while waiting
.macro CIN_WAIT_KEY
    push event
cin_wait_key_loop_%:
    CB_POP events_buffer, events_buffer_length, event
    brts @1 ; Branch if empty (T=1)

cin_key_%:   
    cpi event, @0
    brne cin_wait_key_loop_%

cin_wait_key_end_%:
    pop event
.endmacro