; Recording library for sound.asm
; TODO preserve recording (option to erase it)
; TODO use nibble (4bit instead of 8bit) since note index < 7
; TODO save / load the recording from / into EEPROM

.equ record_buffer_length = 13
.dseg
record_buffer:
    .byte 1
    .byte 1
    .byte 1
    .byte record_buffer_length

.cseg
record_init:
    CB_init record_buffer

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