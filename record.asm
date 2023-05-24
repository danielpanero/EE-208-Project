; Recording library for sound.asm
; TODO save / load the recording from / into EEPROM
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