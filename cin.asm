
.def command = r18

.equ REMOTE_PERIOD = 1778		

.equ ARROW_UP = 0x20
.equ ARROW_DOWN = 0x21

.equ ENTER = 0x38

.equ YES = 0x0B
.equ NO = 0x0C

.equ MAX_NUMBER_RANGE = 0x09

.equ events_buffer_length = 12
.dseg
events_buffer:
    .byte 1
    .byte 1
    .byte 1
    .byte events_buffer_length

.cseg
cin_init:
    CB_init events_buffer
    OUTI EIMSK, 0b10000000
    ret

cin_remote_service_routine:
    in _sreg, SREG
    PUSHX
    PUSH4 b0, b1, b2, b3, _sreg
    CLR4 b0, b1, b2, b3

    ldi b2, 14
    cli

cin_remote_service_routine_loop:
	P2C			PINE,IR			; move Pin to Carry (P2C)
	ROL2		b1,b0			; roll carry into 2-byte reg
	WAIT_US		(REMOTE_PERIOD-4)			; wait bit period (- compensation)	
	DJNZ		b2, cin_remote_service_routine_loop		; Decrement and Jump if Not Zero

    ; Checking if length of is zero
	lds	b3, events_buffer+_nbr

    ;DBREGF "Command :", FHEX, b0
    ;DBREGF "Length:", FDEC, b3 

    tst b3
    brne PC+2
    rjmp cin_remote_service_push_back
	

    ; Taking out the last element of the buffer
    clr xh
	lds	xl, events_buffer+_in

    subi xl, low(-events_buffer-_beg + 1)
	sbci xh,high(-events_buffer-_beg + 1) ; add in-pointer to buffer base

    ld b3, x

    ;DBREGF "Last command :", FHEX, b3
    cp b0, b3

    breq cin_remote_service_routine_end

cin_remote_service_push_back:
    ;DBREGF "Pushed back: ", FDEC, b0
    CB_push events_buffer, events_buffer_length, b0
    
cin_remote_service_routine_end:
    POPX
    POP4 b0, b1, b2, b3, _sreg
    out SREG, _sreg
    reti

.macro CIN_FLUSH
    CB_init events_buffer
.endmacro

; in @0 register, @1 lower limit, @2 upper limit, @3 address for updating the screen while waiting
.macro CIN_CYCLIC
    push command
cin_cyclic_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brts @3 ; Branch if empty (T=1)

cin_cyclic_enter_%
    cpi command, ENTER
    breq cin_cyclic_end_%

cin_cyclic_arrow_up_%:   
    cpi command, ARROW_UP
    brne cin_cyclic_arrow_down_%
    INC_CYC @0, @1, @2
cin_cyclic_arrow_down_%:   
    cpi command, ARROW_DOWN
    brne cin_cyclic_loop_%
    DEC_CYC @0, @1, @2

    rjmp cin_cyclic_loop_%

cin_cyclic_end_%:
    pop command
.endmacro

; in @0 register, @1 address for updating the screen while waiting
.macro CIN_NUM
    PUSH3 command, a0, b0, c0
cin_num_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brts @3 ; Branch if empty (T=1)

cin_num_enter_%
    cpi command, ENTER
    breq cin_num_end_%

cin_num_%:
    ; Check if it is a number
    cpi command, MAX_NUMBER_RANGE + 1
    brsh cin_num_end_%

    ; Multiply the number before by ten
    mov a0, @0
    ldi b0, 10
    
    rcall mul11

    ; Add the event number
    mov @0, c0
    add @0, command

    ; Checking for overflow
    brcc PC+2
    mov @0, command

    rjmp cin_num_loop_%


cin_num_end_%:
    POP3 command, a0, b0, c0
.endmacro

; in @0 address for updating the screen while waiting
.macro CIN_YES_NO
    push command
cin_yes_no_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brts @0 ; Branch if empty (T=1)

cin_yes_%:   
    cpi command, YES
    brne cin_no_%
    set
    rjmp cin_yes_no_end_
cin_no_%:   
    cpi command, NO
    brne cin_yes_no_loop_%
    clt
    rjmp cin_yes_no_end_
cin_yes_no_end_%:
    pop command
.endmacro

; in @0 key to wait, @1 address for updating the screen while waiting
.macro CIN_WAIT_KEY
    push command
cin_wait_key_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brts @1 ; Branch if empty (T=1)

cin_key_%:   
    cpi command, @0
    brne cin_wait_key_loop_%

cin_wait_key_end_%:
    pop command
.endmacro