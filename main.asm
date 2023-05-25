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

; Custom macros
.macro WJP1
; in port, bit, timeout, address if P=1
	ldi	w,@2+1
	dec	w
	breq	PC+4
	sbis	@0,@1
	rjmp	PC-3	
    rjmp    @3 ; Jumps if P=1
.endmacro


.macro SWJP1
; in port, bit, timeout, address if P=1, address if timeout
	ldi	w,@2+1
	dec	w
	brne	PC+2
    rjmp    @4 ; Jumps if time out
	sbis	@0,@1
	rjmp	PC-4	
    rjmp    @3 ; Jumps if P=1
.endmacro

reset:
    LDSP RAMEND ; Load stack pointer SP
    sei ; Activate interrupts

    ; Library initializations: 
    rcall LCD_init
    rcall UART0_init 
    rcall eeprom_init


    ; FIXME check why it doesn't exactly as LDI
    ;EEPROM_WRITE duration_address, 0x01 ; Preloading the EEPROM (to be removed using the settings)!!!!! 
    rcall sound_init
    rcall record_init
    rcall analog_init

    OUTI DDRD, 0 ; Buttons

    ldi status_flag, 0b00000000 ; Menu at start

    rjmp main

; TODO Replace bit constant with correct equ
; TODO Status flag management
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

; TODO replace it with menu
waiting:
    ;DBMSG "Waiting"
    PRINTF LCD_putc
    .db CR,CR, "Waiting", "     ", CR, 0
    ret

; Plays the sound without recording
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
; IDEA implement screen notes or how much spaces in the buffer is left
play_and_record:
    ;DBMSG "Playing and recording"
    PRINTF LCD_putc
    .db CR, CR, "Recording", "       ", CR, 0
    WAIT_MS 1500

    rcall analog_loop

    clr note_index 
    rcall loop_normalize_note_index
    rcall play_note

    rcall record_push

    brtc PC+2
    rcall stop_record; If the buffer is full

    ret

; Plays the sound from the recording it
; TODO implement buffer overflow mode
; TODO implement screen
; TODO implement test for zero to check end
play_from_record:
    ;DBMSG "Play from record"
    PRINTF LCD_putc
    .db CR, CR, "Play back", "      ", CR, 0
    WAIT_MS 5000

    rcall record_pop

    brtc PC+2
    rcall stop_record; If the buffer arrives at the end

    rcall play_note
    ret


; Stops the recording
stop_record:
    ;DBMSG "Record stopped"
    PRINTF LCD_putc
    .db CR, CR, "Record stopped", "     ", CR, 0

    WAIT_MS 1500
    PRINTF LCD_putc
    .db CR, CR, "Do you want to listen to it?", CR, 0
    WAIT_MS 2500

    WJP1 PIND, 0, 254, rewind_record_and_play

    PRINTF LCD_putc
    .db "Do you want to rewind the recording?", CR, 0
    WAIT_MS 2500

    SWJP1 PIND, 0, 254, restart_record, rewind_record_and_record

; Restarts the recording from the same point
restart_record:
    ;DBMSG "Record restarted"
    PRINTF LCD_putc
    .db CR, CR, "Record restarted", "     ", CR, 0
    WAIT_MS 2500

    rjmp play_and_record

; It rewinds and start to record the music again
rewind_record_and_record:
    ;DBMSG "Record rewinded"
    PRINTF LCD_putc
    .db CR, CR, "Record rewinded", "     ", CR, 0
    WAIT_MS 2500
    
    rcall record_rewind
    rjmp play_and_record

; It rewinds and start to play the music again
rewind_record_and_play:
    ;DBMSG "Record rewinded"
    PRINTF LCD_putc
    .db CR, CR, "Record rewinded", "     ", CR, 0
    WAIT_MS 2500

    rcall record_rewind
    rjmp play_from_record


; It saves note length in the EEPROM
; TODO interface for input the duration
save_note_length:
    ;ldi r12, 0xF5
    ;EEPROM_WRITE_REG duration_address, r12
    ret

; It loads the record from the EEPROM
; TODO interface
; TODO automatically do it when loading
load_record:
    rcall record_load_EEPROM
    ret

; It saves the record to the EEPROM
; TODO interface
save_record:
    rcall record_save_EEPROM
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