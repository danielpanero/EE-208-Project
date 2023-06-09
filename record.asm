; file:	record.asm   target ATmega128L-4MHz-STK300
; Recording library for sound.asm
; Copyright 2023: Daniel Panero (342800), Yasmina Jemili (310507)

.equ record_buffer_length = 240
.dseg
record_buffer:
    .byte 1
    .byte 1
    .byte 1
    .byte record_buffer_length

.cseg
record_init:
    CB_init record_buffer
    rcall record_load_EEPROM
    ret

record_push:
    push a0
    mov a0, note_index

    CB_push record_buffer, record_buffer_length, a0
    pop a0

    ret

record_pop:
    push a0

    CB_POP_PRESERVE record_buffer, record_buffer_length, a0
    mov note_index, a0
    pop a0 
    ret

record_clear:
    CB_init record_buffer
    rcall record_save_EEPROM
    ret

record_rewind:
    STI	record_buffer+_out, 0
    ret
    
record_load_EEPROM:
    push a0 ; Saveguarding scratch registers : a0 element, a1 length of the buffer
    push a1

    WAIT_MS 2
    CA i2c_start,EEPROM ; Starting the communication
    CA i2c_write, high(record_buffer)
	CA i2c_write, low(record_buffer)

    CA i2c_rep_start,EEPROM + R

    ;Loading the first four special bits
    LDIX record_buffer

    rcall i2c_read
    rcall i2c_ack
    
    ldi a0, 0
    st X+, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    mov a1, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    tst a1 ; Testing whether the saved buffer is empty
    brne PC+2
    rjmp record_load_end

    rcall record_rewind; Rewinding the record

    push a1 ; Saveguarding the length

record_load_loop:

    rcall i2c_read
    rcall i2c_ack
    CB_push record_buffer, record_buffer_length, a0

    dec a1

    brne PC+3 ; Testing whether it reached the end
    pop a1 ; Restoring the length
    rjmp record_load_end

    rjmp record_load_loop

record_load_end:
    rcall i2c_no_ack
    rcall i2c_stop
    WAIT_US 2000

    sts record_buffer+_nbr, a1 ; Saving the length as before we had to set to zero in order to start from the beginning
    STI	record_buffer+_out, 0 ; Rewinding the record
    pop a1
    pop a0 ; Restoring scratch registers
    ret

record_save_EEPROM:
    push a0 ; Saveguarding scratch registers : a0 element, a1 length of the buffer
    push a1

    STI	record_buffer+_out, 0 ; Rewinding the record

    ; Saving the first four special bits

    WAIT_US 2000
    CA i2c_start, EEPROM ; Starting the communication
    CA i2c_write, high(record_buffer)
	CA i2c_write, low(record_buffer)
    LDIX record_buffer

    ld a0, X+
    rcall i2c_write

    ld a0, X+
    rcall i2c_write

    ld a0, X+
    rcall i2c_write

    mov a1, a0

    ld a0, X+
    rcall i2c_write 

    tst a1 ; Testing whether the buffer is empty
    brne PC+2
    rjmp record_save_end

record_save_loop:
    ; Saving the buffer
    CB_POP_PRESERVE record_buffer, record_buffer_length, a0

    brtc PC+3
    rcall i2c_write
    rjmp record_save_end ; If it reaches the end of the buffer it ends the communication

    rcall i2c_write
    rjmp record_save_loop


record_save_end:
    rcall i2c_stop
    WAIT_US 2000

    STI	record_buffer+_out, 0 ; Rewinding the record
    
    pop a1
    pop a0 ; Restoring scratch registers
    ret