; Recording library for sound.asm
; TODO rename a0, a1
; TODO clean up
; IDEA implement progress reading / writing buffer
; IDEA use nibble (4bit instead of 8bit) since note index < 7
; IDEA multiple recordings

.equ record_buffer_length = 3
.dseg
record_buffer:
    .byte 1
    .byte 1
    .byte 1
    .byte record_buffer_length

; TODO once default settings initialized when record_init automatically call record_load_EEPROM
.cseg
record_init:
    CB_init record_buffer
    ret

record_push:
    push a0
    mov a0, note_index

    CB_push record_buffer, record_buffer_length, a0
    pop a0

    ret

record_pop:
    push a0

    CB_POP record_buffer, record_buffer_length, a0
    mov note_index, a0
    pop a0 
    ret

record_clear:
    CB_init record_buffer
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

    ; Loading the first four special bits
    LDIX record_buffer

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    ;DBREGF "Loading 1.0: ", FDEC, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    ;DBREGF "Loading 2.0: ", FDEC, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    mov a1, a0

    ;DBREGF "Loading 3.0: ", FDEC, a0

    rcall i2c_read
    rcall i2c_ack
    st X+, a0

    ;DBREGF "Loading 4.0: ", FDEC, a0

    tst a1 ; Testing whether the saved buffer is empty
    brne PC+2
    rjmp record_load_save_end

    rcall record_clear; Rewinding the record

record_load_loop:

    rcall i2c_read
    rcall i2c_ack
    CB_push record_buffer, record_buffer_length, a0

    ;DBSREG "SREG :"

    ;DBREGF "Loading note loop: ", FDEC, a0

    dec a1
    ;DBREGF "Loading note index: ", FDEC, a1

    brne PC+3 ; Testing whether it reached the end
    rcall i2c_no_ack
    rjmp record_load_save_end

    rjmp record_load_loop

record_save_EEPROM:
    push a0 ; Saveguarding scratch registers : a0 element, a1 length of the buffer
    push a1

    STI	record_buffer+_out, 0 ; Rewinding the record

    WAIT_MS 2
    CA i2c_start, EEPROM ; Starting the communication
    CA i2c_write, high(record_buffer)
	CA i2c_write, low(record_buffer)

    ; Saving the first four special bits
    LDIX record_buffer

    ld a0, X+
    rcall i2c_write

    ;DBREGF "Saving 1bit: ", FDEC, a0

    ld a0, X+
    rcall i2c_write

    ;DBREGF "Saving 2bit: ", FDEC, a0

    ld a0, X+
    rcall i2c_write

    mov a1, a0

    ;DBREGF "Saving 3bit: ", FDEC, a0

    ld a0, X+
    rcall i2c_write

    ;DBREGF "Saving 4bit: ", FDEC, a0

    tst a1 ; Testing whether the buffer is empty
    brne PC+2
    rjmp record_load_save_end

record_save_loop:
    ; Saving the buffer
    CB_POP record_buffer, record_buffer_length, a0

    ;DBREGF "Saving note loop: ", FDEC, a0

    brtc PC+3
    rcall i2c_write
    rjmp record_load_save_end ; If it reaches the end of the buffer it ends the communication

    rcall i2c_write
    rjmp record_save_loop


record_load_save_end:
    rcall i2c_stop
    WAIT_MS 2

    STI	record_buffer+_out, 0 ; Rewinding the record
    
    pop a1
    pop a0 ; Restoring scratch registers
    ret