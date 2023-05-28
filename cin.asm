
.def command = r20

.equ REMOTE_PERIOD = 1778		

.equ ARROW_UP = 0x20
.equ ARROW_DOWN = 0x21

.equ ENTER = 0x38

.equ YES = 0x10
.equ NO = 0x11

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
    cli
    in _sreg, SREG

    PUSH5 b0, b1, b2, b3, _sreg
    PUSHX
    PUSHY
    PUSHZ

    CLR4 b0, b1, b2, b3

    ldi b2, 14

cin_remote_service_routine_loop:
	P2C			PINE,IR			; move Pin to Carry (P2C)
	ROL2		b1,b0			; roll carry into 2-byte reg
	WAIT_US		(REMOTE_PERIOD-4)			; wait bit period (- compensation)	
	DJNZ		b2, cin_remote_service_routine_loop		; Decrement and Jump if Not Zero

    ;DBREGF "Command b1:", FHEX, b1
    ;DBREGF "Command:", FHEX, b0

    ; Checking if length of is zero
	lds	b3, events_buffer+_nbr

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
    CB_push events_buffer, events_buffer_length, b0
    ;DBREGF "Pushed back: ", FHEX, b0
    
cin_remote_service_routine_end:
    ;DBMSG "End service routine"

    WAIT_US REMOTE_PERIOD
    
    POPZ
    POPY
    POPX
    POP5 b0, b1, b2, b3, _sreg
    out SREG, _sreg
    ret

.macro CIN_FLUSH
    CB_init events_buffer
.endmacro

; in @0 register, @1 lower limit, @2 upper limit, @3 address for updating the screen while waiting
.macro CIN_CYCLIC
    ;DBMSG "Start:"
    cli
    push command

    clr command
cin_cyclic_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    ;DBSREG "SREG cyclic: "
    brtc PC+2
    rjmp cin_cyclic_return_%  ; Branch if empty (T=1)

    ;DBREGF "Command cyclic: ", FHEX, command
cin_cyclic_enter_%:
    cpi command, ENTER
    brne PC+2
    rjmp cin_cyclic_end_%

cin_cyclic_arrow_up_%:   
    cpi command, ARROW_UP
    breq PC+2
    rjmp cin_cyclic_arrow_down_%
    
    INC_CYC @0, @1, @2
    ;DBREGF "Up:", FDEC, @0
cin_cyclic_arrow_down_%:   
    cpi command, ARROW_DOWN
    breq PC+2
    rjmp cin_cyclic_loop_%

    DEC_CYC @0, @1, @2
    ;DBREGF "Down:", FDEC, @0
    rjmp cin_cyclic_loop_%
cin_cyclic_return_%:
    ;DBMSG "Redrawing: "
    pop command
    sei
    rjmp @3

cin_cyclic_end_%:
    ;DBMSG "Ending: "
    pop command
    sei

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
    cli
    push command
    clr command
cin_yes_no_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    ;DBREGF "Command yes no loop: ", FHEX, command

    brtc PC+2
    rjmp cin_yes_no_ret_% ; Branch if empty (T=1)

cin_yes_%:   
    cpi command, YES
    breq PC+2
    rjmp cin_no_%

    set
    rjmp cin_yes_no_end_%
cin_no_%:   
    cpi command, NO
    breq PC+2
    rjmp cin_yes_no_loop_%

    clt
    rjmp cin_yes_no_end_%

cin_yes_no_ret_%:
    pop command
    sei
    rjmp @0

cin_yes_no_end_%:
    pop command
    sei
.endmacro

; in @0 key to wait, @1 address for updating the screen while waiting
.macro CIN_WAIT_KEY
    cli
    push command
    clr command
cin_wait_key_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_wait_key_return_% ; Branch if empty (T=1)

    ;DBREGF "Command cyclic: ", FHEX, command

cin_key_%:   
    cpi command, @0
    brne cin_wait_key_loop_%
    rjmp cin_wait_key_end_%

cin_wait_key_return_%:
    pop command
    sei
    rjmp @1

cin_wait_key_end_%:
    pop command
    sei
.endmacro