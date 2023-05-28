.include "m128def.inc"
.include "definitions.asm"
.include "macros.asm"

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

; Scratch variables
.def var = r23

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

    ;EEPROM_WRITE threshold_address, 15 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 
    ;EEPROM_WRITE duration_address, 100 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 
    ;EEPROM_WRITE scale_address, 0 ; FIXME Preloading the EEPROM (to be removed using the settings)!!!!! 

    rcall sound_init
    rcall record_init
    rcall analog_init
    rcall cin_init

    OUTI DDRD, 0 ; Buttons

    rjmp main

.equ PLAYING = 0
.equ REPLAYING = 1
.equ SETTINGS_MENU = 2

.equ SETTINGS_MENU_SCALES = 0
.equ SETTINGS_MENU_DURATION = 1
.equ SETTINGS_MENU_THRESHOLD = 2

; ========================================================================================
; Main menu
main:
    clr var
    rcall lcd_clear
main_loop:
main_loop_play_text:
    cpi var, PLAYING
    brne main_loop_replay_text

    PRINTF LCD_putc
    .db CR, CR, "<==== Play ====>" , CR, 0

    rjmp main_loop_end

main_loop_replay_text:
    cpi var, REPLAYING
    brne main_loop_settings_text

    PRINTF LCD_putc
    .db CR,CR, "<=== Replay ===>", CR, 0

    rjmp main_loop_end

main_loop_settings_text:
    cpi var, SETTINGS_MENU

    PRINTF LCD_putc
    .db CR,CR, "<== Settings ==>", CR, 0

    rjmp main_loop_end

main_loop_end:
    CIN_CYCLIC var, PLAYING, SETTINGS_MENU, main_loop

main_loop_jmp_tbl:
    cpi var, PLAYING
    brne PC+2
    rjmp play

    cpi var, REPLAYING
    brne PC+2
    rjmp play_from_record

    cpi var, SETTINGS_MENU
    brne PC+2
    rjmp settings

    rjmp main

; ========================================================================================
; Main > Play menu
play:
    PRINTF LCD_putc
    .db CR, CR, "Recording? [Y/N]", 0
play_loop:
    CIN_YES_NO play_loop

play_loop_jmp_tbl:
    brts PC + 2
    rjmp play_free
    rjmp play_and_record
    

; ========================================================================================
; Main > Play > Play free
play_free:
    rcall LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Playing free", "       ", CR, 0

    rjmp play_free_loop

play_free_sound_mute_unmute:
    INVP DDRE, SPEAKER

play_free_loop:
    rcall analog_loop
    rcall sound_play_note

    CIN_WAIT_KEY2 HOME, main, MUTE, play_free_sound_mute_unmute
    rjmp play_free_loop

; ========================================================================================
; Menu > Play > Play and record

; IDEA implement screen notes or how much spaces in the buffer is left
play_and_record:
    rcall record_clear
    rcall LCD_clear

    PRINTF LCD_putc
    .db CR, CR, "Recording", "       ", CR, 0
    rjmp play_and_record_loop

play_and_record_sound_mute_unmute:
    INVP DDRE, SPEAKER

play_and_record_loop:   
    rcall analog_loop
    rcall sound_play_note

    rcall record_push

    brtc PC+2
    rcall play_and_record_stop; If the buffer is full

    CIN_WAIT_KEY3 HOME, main, MUTE, play_and_record_sound_mute_unmute, STOP, play_and_record_stop
    rjmp play_and_record_loop

play_and_record_stop:
    rcall LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Playback? [Y/N]", 0

play_and_record_stop_loop:
    CIN_YES_NO play_and_record_stop_loop

play_and_record_stop_jmp_tbl:
    brts PC + 2
    rjmp play_and_record
    rjmp play_from_record


; ========================================================================================
; Menu > Playback

; TODO checking if buffer is empty before playing back
; TODO 
play_from_record:
    rcall LCD_clear
    rcall record_rewind

    ; check if buffer is empty
    lds	b3, record_buffer+_nbr
    tst b3
    brne play_from_record_not_empty
    PRINTF LCD_putc
    .db CR, CR, "Nothing to play!", 0
    WAIT_MS 1000
    rjmp main
    
play_from_record_not_empty:
    PRINTF LCD_putc
    .db CR, CR, "Playing back", 0

    rjmp play_from_record_loop

play_from_record_sound_mute_unmute:
    INVP DDRE, SPEAKER

play_from_record_loop:
    rcall record_pop

    brtc PC+2
    rcall play_from_record_stop; If the buffer is empty

    rcall sound_play_note

    CIN_WAIT_KEY3 HOME, main, MUTE, play_from_record_sound_mute_unmute, STOP, play_from_record_stop
    rjmp play_from_record_loop

play_from_record_stop:
    rcall LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "One more time? [Y/N]", 0

play_from_record_stop_loop:
    CIN_YES_NO play_from_record_stop_loop

play_from_record_stop_jmp_tbl:
    brtc PC + 2
    rjmp play_from_record_loop
    rjmp main


; ========================================================================================
; Settings menu
settings:
    clr var
    rcall LCD_clear
settings_loop:
settings_loop_scales_text:
    cpi var, SETTINGS_MENU_SCALES
    brne settings_loop_duration_text

    PRINTF LCD_putc
    .db CR,CR, "<===  Scale  ===>", CR, 0
    rjmp settings_loop_end

settings_loop_duration_text:
    cpi var, SETTINGS_MENU_DURATION
    brne settings_loop_threshold_text

    PRINTF LCD_putc
    .db CR,CR, "<== Duration ==>", CR, 0
    rjmp settings_loop_end

settings_loop_threshold_text:
    cpi var, SETTINGS_MENU_THRESHOLD

    PRINTF LCD_putc
    .db CR,CR, "<= Threshold  =>", CR, 0
    rjmp settings_loop_end

settings_loop_end:
    CIN_CYCLIC var, SETTINGS_MENU_SCALES, SETTINGS_MENU_THRESHOLD, settings_loop

settings_loop_jmp_tbl:
    cpi var, SETTINGS_MENU_SCALES
    brne PC+2
    rjmp settings_scales

    cpi var, SETTINGS_MENU_DURATION
    brne PC+2
    rjmp settings_duration

    cpi var, SETTINGS_MENU_THRESHOLD
    brne PC+2
    rjmp settings

    rjmp settings

; ========================================================================================
; Settings > Scales

settings_scales:
    EEPROM_READ scale_address, b0

    call LCD_clear
settings_scales_loop:
    PRINTF LCD_putc
    .db CR, CR, "Scale =", FDEC|FDIG1, b, "/5", CR, 0

    CIN_CYCLIC b0, scales_tbl_index_min, scales_tbl_index_max, settings_scales_loop

    EEPROM_WRITE_REG scale_address, b0
    sts scale_address, b0

    rjmp main

; ========================================================================================
; Settings > Duration

settings_duration:
    EEPROM_READ duration_address, d0

    call LCD_clear
settings_duration_loop:
    PRINTF LCD_putc
    .db CR, CR, "Duration =", FDEC|FDIG3, d, "/25 ms", 0

    CIN_NUM d0, settings_duration_loop

    EEPROM_WRITE_REG duration_address, d0
    sts duration_address, d0

    rjmp main