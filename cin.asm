; file:	cin.asm   target ATmega128L-4MHz-STK300
; Cin library used to treat the event sent by the remote
; Copyright 2023: Daniel Panero (342800), Yasmina Jemili (310507)

.def command = r20

.equ REMOTE_PERIOD = 1778		

.equ ARROW_UP = 0x20
.equ ARROW_DOWN = 0x21

.equ ENTER = 0x38
.equ HOME = 0x22
.equ STOP = 0x00
.equ MUTE = 0x0d

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

    cpi b0, 0xff ; Checking if failed
    brne PC+2
    rjmp cin_remote_service_routine_end

    ; Checking if length of buffer is zero
	lds	b3, events_buffer+_nbr

    tst b3
    brne PC+2
    rjmp cin_remote_service_push_back
	

    ; Taking out the last element of the buffer
    clr xh
	lds	xl, events_buffer+_in

    subi xl, low(-events_buffer-_beg + 1)
	sbci xh,high(-events_buffer-_beg + 1) ; add in-pointer to buffer base

    ld b3, x

    cp b0, b3

    breq cin_remote_service_routine_end

cin_remote_service_push_back:
    CB_push events_buffer, events_buffer_length, b0
    
cin_remote_service_routine_end:

    WAIT_MS REMOTE_PERIOD / 8

    POPZ
    POPY
    POPX
    POP5 b0, b1, b2, b3, _sreg
    out SREG, _sreg
    ret

.macro CIN_FLUSH
    CB_init events_buffer
.endmacro

; in @0 register, @1 lower limit, @2 upper limit, @3 address for updating the screen while waiting, @4 interrupt key, @5 interrupt address
.macro CIN_CYCLIC
    cli
    push command

    clr command
cin_cyclic_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_cyclic_return_%  ; Branch if empty (T=1)

cin_cyclic_enter_%:
    cpi command, ENTER
    brne PC+2
    rjmp cin_cyclic_end_%

cin_cyclic_key_interrupt%:   
    cpi command, @4
    brne PC+2
    rjmp @5

cin_cyclic_arrow_up_%:   
    cpi command, ARROW_UP
    breq PC+2
    rjmp cin_cyclic_arrow_down_%
    
    INC_CYC @0, @1, @2
cin_cyclic_arrow_down_%:   
    cpi command, ARROW_DOWN
    breq PC+2
    rjmp cin_cyclic_loop_%

    DEC_CYC @0, @1, @2
    rjmp cin_cyclic_loop_%
cin_cyclic_return_%:
    pop command
    sei
    rjmp @3

cin_cyclic_end_%:
    pop command
    sei

.endmacro

; in @0 register, @1 address for updating the screen while waiting
.macro CIN_NUM
    cli
    PUSH5 command, a0, b0, c0, c1
cin_num_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_num_ret_% ; Branch if empty (T=1)

cin_num_enter_%:
    cpi command, ENTER
    brne PC+2
    rjmp cin_num_end_%

cin_num_%:
    ; Check if it is a number
    cpi command, MAX_NUMBER_RANGE + 1

    brlo PC+2
    rjmp cin_num_loop_%

    ; Multiply the number before by ten
    CLR2 c0, c1

    mov a0, @0
    ldi b0, 10
    
    call mul11

    _cpi c1, 0x00
    breq PC+3
    mov @0, command
    rjmp cin_num_loop_%

    ; Add the event number
    mov @0, c0
    add @0, command

    ; Checking for overflow
    brcc PC+2
    mov @0, command

    rjmp cin_num_loop_%

cin_num_ret_%:
    POP5 command, a0, b0, c0, c1
    sei
    jmp @1

cin_num_end_%:
    POP5 command, a0, b0, c0, c1
    sei
.endmacro

; in @0 register, @1 lower limit, @2 upper limit, @3 address for updating the screen while waiting
.macro CIN_NUM_CYC
    cli
    PUSH5 command, a0, b0, c0, c1
cin_num_cyc_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_num_cyc_ret_% ; Branch if empty (T=1)

cin_num_cyc_enter_%:
    cpi command, ENTER
    brne PC+2
    rjmp cin_num_cyc_end_%

cin_num_cyc_%:
    ; Check if it is a number
    cpi command, MAX_NUMBER_RANGE + 1

    brlo PC+2
    rjmp cin_num_cyc_loop_%

    ; Multiply the number before by ten
    CLR2 c0, c1

    mov a0, @0
    ldi b0, 10
    
    call mul11

    _cpi c1, 0x00
    breq PC+4
    _ldi @0, @2
    rjmp cin_num_cyc_loop_%

    ; Add the event number
    mov @0, c0
    add @0, command

    ; Checking for overflow
    brcc PC+3
    _ldi @0, @2

    ; Checking if higher
    _cpi @0, @2
    brlo PC+3    
    _ldi @0, @2

    rjmp cin_num_cyc_loop_%

cin_num_cyc_ret_%:
    POP5 command, a0, b0, c0, c1
    sei
    jmp @3

cin_num_cyc_end_%:
    POP5 command, a0, b0, c0, c1
    sei
.endmacro

; in @0 address for updating the screen while waiting, @1 interrupt key, @2 interrupt address
.macro CIN_YES_NO
    cli
    push command
    clr command
cin_yes_no_loop_%:
    CB_POP events_buffer, events_buffer_length, command

    brtc PC+2
    rjmp cin_yes_no_ret_% ; Branch if empty (T=1)

cin_cyclic_key_interrupt%:   
    cpi command, @1
    brne PC+2
    rjmp @2

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

; in @0 key 1, @1 address 1, @2 key 2, @3 address 2
.macro CIN_WAIT_KEY2
    cli
    push command
    clr command
cin_wait_key2_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_wait_key2_return_% ; Branch if empty (T=1)

cin_key_21_%:   
    cpi command, @0
    brne cin_key_22_%

    pop command
    sei
    rjmp @1

cin_key_22_%:   
    cpi command, @2
    brne cin_wait_key2_loop_%
    
    pop command
    sei
    rjmp @3

cin_wait_key2_return_%:
    pop command
    sei
.endmacro


; in @0 key 1, @1 address 1, @2 key 2, @3 address 2, @4 key 3, @5 address 3
.macro CIN_WAIT_KEY3
    cli
    push command
    clr command
cin_wait_key3_loop_%:
    CB_POP events_buffer, events_buffer_length, command
    brtc PC+2
    rjmp cin_wait_key3_return_% ; Branch if empty (T=1)

cin_key_31_%:   
    cpi command, @0
    brne cin_key_32_%

    pop command
    sei
    rjmp @1

cin_key_32_%:   
    cpi command, @2
    brne cin_key_33_%
    
    pop command
    sei
    rjmp @3


cin_key_33_%:   
    cpi command, @4
    brne cin_wait_key3_loop_%
    
    pop command
    sei
    rjmp @5

cin_wait_key3_return_%:
    pop command
    sei
.endmacro