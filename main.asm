.include "m128def.inc"
.include "macros.asm"
.include "definitions.asm"

.org 0
    rjmp reset


.org ADCCaddr
	jmp	analog_service_routine


.include "lcd.asm"	
.include "printf.asm"
.include "buffer.asm"
.include "uart.asm"
.include "i2cx.asm"
.include "debug.asm"

; Global variables
.def note_index = r21

.include "eeprom.asm"
.include "sound.asm"
.include "record.asm"
.include "analog.asm"


; Global status flag definitions
.def status_flag = r22
.def _status_flag = r23
.equ MODE = 1
.equ MODEMSK = 0b00000011

.equ MODE_WAITING = 0b00
.equ MODE_PLAY = 0b01

.equ PLAY_MODE = 3
.equ PLAY_MODEMSK = 0b00001100

.equ PLAY_MODE_FREE = 0b00
.equ PLAY_MODE_RECORD = 0b01
.equ PLAY_MODE_FROM_RECORD = 0b11

reset:
    LDSP RAMEND ; Load stack pointer SP
    sei ; Activate interrupts

    ; Library initializations: 
    rcall LCD_init
    rcall UART0_init 
    rcall eeprom_init
    rcall sound_init
    rcall record_init
    rcall analog_init

    OUTI DDRD, 0 ; Buttons

    ldi status_flag, 0b00000101
    rjmp main

; TODO Replace bit constant with correct equ
main:   
    ; This part will make sense when using the interrupt as the buttons don't have one, having a status flag is more or less useless
    JP1 PIND, 0, PC+3
    INVB status_flag, 0
    JP1 PIND, 1,  PC+3
    INVB status_flag, 2
    JP1 PIND, 2, PC+3
    INVB status_flag, 3
    
    ;DBREG "Status flag 0:", status_flag

    push _status_flag ; Preserving scratch register content

    ;1. Determining the mode
    mov _status_flag, status_flag
    andi _status_flag, MODEMSK
    ;DBREG "Status flag 1:", _status_flag

    cpi _status_flag, 0b00000000; Check if waiting
    brne PC+4
    pop _status_flag
    rcall waiting
    rjmp main

    ;2. Determining the play mode
    mov _status_flag, status_flag
    andi _status_flag, PLAY_MODEMSK
    ;DBREG "Status flag 2:", _status_flag

    ;2.1. Check if play free mode
    cpi _status_flag, 0b00000000
    brne PC+4
    pop _status_flag
    rcall play_free
    rjmp main

    ;2.2. Check if play and record mode
    cpi _status_flag, 0b00000100
    brne PC+4
    pop _status_flag
    rcall play_and_record
    rjmp main

    ;2.3. Check if play from record mode
    cpi _status_flag, 0b00001100
    brne PC+4
    pop _status_flag
    rcall play_from_record
    rjmp main

    pop _status_flag
    rjmp main

waiting:
    ;DBMSG "Waiting"
    PRINTF LCD_putc
    .db CR,CR, "Waiting", "     ", CR, 0
    ret

; Plays the sound with recording
play_free:
    ;DBMSG "Playing free"
    PRINTF LCD_putc
    .db CR, CR, "Playing free", "     ", CR, 0

    rcall analog_loop

    clr note_index 
    rcall loop_normalize_note_index
    rcall play_note
    ret


; Plays the sound and records it
; TODO implement buffer overflow mode 
; TODO implement screen
play_and_record:
    ;DBMSG "Playing and recording"
    PRINTF LCD_putc
    .db CR, CR, "Recording", "       ", CR, 0

    rcall analog_loop

    clr note_index 
    rcall loop_normalize_note_index
    rcall play_note

    rcall record_push

    brtc PC+2 ; If buffer didn't overflow
    ldi status_flag, 0b00001101 ; If buffer overflew, changes back to waiting

    ret

; Plays the sound from the recording it
; TODO implement buffer overflow mode
; TODO implement screen
play_from_record:
    ;DBMSG "Play from record"
    PRINTF LCD_putc
    .db CR, CR, "Play back", "     ", CR, 0

    rcall record_pop
    brtc PC+2 ; If buffer didn't overflow
    ldi status_flag, 0b00000000 ; If buffer overflew, changes back to waiting

    rcall play_note
    ret

; Plays a note selected using scale selection and the index of note (preloaded)
; TODO implement scale selection
; TODO Implement screen text
play_note:
    ; Going through the notes_tbl: note_index = 0 --> lowest note, note_index = 23 --> highest note:
    LDIZ 2*(notes_tbl_do)
    ADDZ note_index

    lpm

    mov period, r0

    rcall sound
    ret


; TODO better transition between notes / more stable transition (increasing the length of the note / adding 10% margin before switching)
loop_normalize_note_index:
    inc note_index

    ;DBREGSF "Analog: ", FDEC2, analogh, analogl
    SUBI2 analogh, analogl, analog_max_value / (notes_tbl_index_max+2)  ; We choosed to place a note every 40 dec
    ;DBSREG "SREG: "
    JC0 loop_normalize_note_index ; If analogh:analog_loop > 40, we can still make an higher note

    dec note_index

    cpi note_index, notes_tbl_index_min ; note_index must be >= 0
    brsh PC+2 
    ldi note_index, notes_tbl_index_min

    cpi note_index, notes_tbl_index_max + 1 ; note_index must be <= 23
    brlo PC+2
    ldi note_index, notes_tbl_index_max

    ;DBREGF "Final note found was: ", FDEC, note_index
    ret
