.include "m128def.inc"
.include "macros.asm"
.include "definitions.asm"

.org 0
    rjmp reset


.org INT7addr
    jmp cin_remote_service_routine

.org ADCCaddr
	jmp	analog_service_routine


.include "math.asm"
.include "lcd.asm"	
.include "printf.asm"
.include "buffer.asm"
.include "uart.asm"
.include "i2cx.asm"
.include "debug.asm"

; Global variables (+analog_flag=r20 --> to be removed)
.def note_index = r21

.include "eeprom.asm"
.include "sound.asm"
.include "record.asm"
.include "analog.asm"
.include "cin.asm"

reset:
    LDSP RAMEND ; Load stack pointer SP
    sei ; Activate interrupts

    ; Library initializations: 
    rcall LCD_init
    rcall UART0_init 
    rcall eeprom_init

    EEPROM_WRITE threshold_address, 15 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 
    EEPROM_WRITE duration_address, 100 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 
    EEPROM_WRITE scale_address, 0 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 

    rcall sound_init
    rcall record_init
    rcall analog_init
    rcall cin_init

    OUTI DDRD, 0 ; Buttons
    OUTI DDRE, 0 ; FIXME change it

    rjmp main


main:
    clr d0
main_loop:
    ;WAIT_MS 100
    
    ;rcall LCD_clear
    CLR3 d1,d2,d3
    PRINTF LCD_putc
    .db CR,CR, "Enter a d0=", FDEC, d, "    ", CR, 0

    CIN_NUM d0, main_loop

    rcall LCD_clear
    PRINTF LCD_putc
    .db CR,CR, "d0=", FDEC, d, CR, 0
end:
    rjmp end

; TODO replace it with menu
waiting:
    ;DBMSG "Waiting"
    PRINTF LCD_putc
    .db CR,CR, "Waiting", "     ", CR, 0
    ret

; Plays the sound without recording
play_free:
    ;DBMSG "Playing free"
    ;PRINTF LCD_putc
    ;.db CR, CR, "Playing free", "     ", CR, 0

    rcall analog_loop
    ;DBREGF "Note index: ", FDEC, note_index
    rcall sound_play_note
    ret


; Plays the sound and records it
; IDEA implement screen notes or how much spaces in the buffer is left
play_and_record:
    ;DBMSG "Playing and recording"
    PRINTF LCD_putc
    .db CR, CR, "Recording", "       ", CR, 0
    WAIT_MS 1500

    rcall analog_loop
    rcall sound_play_note

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
    ;PRINTF LCD_putc
    ;.db CR, CR, "Play back", "      ", CR, 0
    ;WAIT_MS 5000

    rcall record_pop

    DBREGF "Note index", FDEC, note_index

    ;brtc PC+2
    ;rcall stop_record; If the buffer arrives at the end

    rcall sound_play_note
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

    PRINTF LCD_putc
    .db "Do you want to rewind the recording?", CR, 0
    WAIT_MS 2500

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