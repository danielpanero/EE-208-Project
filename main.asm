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

; Global variables (+analog_flag=r20)
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
.equ SETTINGS_MENU_RESET = 3


; ========================================================================================
; Main menu
main:
    clr var
    rcall LCD_clear
main_loop:
    rcall LCD_home
    PRINTF LCD_putc
    .db CR, CR,  "Select mode :   ",  0
    rcall LCD_lf
    
main_loop_play_text:
    cpi var, PLAYING
    brne main_loop_replay_text
    PRINTF LCD_putc
    .db CR, CR, "<==== Play ====>", CR, 0
    
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
    CIN_CYCLIC var, PLAYING, SETTINGS_MENU, main_loop, HOME, main

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
    call LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Recording? [Y/N]", 0
play_loop:
    CIN_YES_NO play_loop, HOME, main

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
    .db CR, CR, "Save recording?", LF, 0
    rcall LCD_lf
    PRINTF LCD_putc
    .db CR, "           [Y/N]", 0

play_and_record_stop_loop:
    CIN_YES_NO play_and_record_stop_loop, HOME, main

play_and_record_stop_jmp_tbl:
    brts PC + 3
    rcall record_clear
    rjmp play

    rcall record_save_EEPROM
    
play_and_record_ask_playback:
    rcall LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Playback? [Y/N]", 0

play_and_record_ask_playback_loop:
    CIN_YES_NO play_and_record_ask_playback_loop, HOME, main

play_and_record_ask_playback_jmp_tbl:
    brts PC + 2
    rjmp play_free

    rjmp play_from_record

; ========================================================================================
; Menu > Playback
; FIXME fix after recording (it works after reset)
play_from_record:
    rcall LCD_clear
    rcall record_rewind

    ; Check if buffer is empty
    lds	b3, record_buffer+_nbr
    tst b3

    breq PC +2
    rjmp play_from_record_not_empty

    PRINTF LCD_putc
    .db CR, CR, "Nothing to play!", 0
    WAIT_MS 1000

play_from_record_empty:
    rcall LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Record? [Y/N]", 0

play_and_record_empty_loop:
    CIN_YES_NO play_and_record_empty_loop, HOME, main

play_and_record_empty_jmp_tbl:
    brtc PC + 2
    rjmp play_and_record
    
    rjmp main
    
play_from_record_not_empty:
    call LCD_clear
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
    .db CR, CR, "One more time? ", LF, 0
    call LCD_lf
    PRINTF LCD_putc
    .db CR, "           [Y/N]", 0

play_from_record_stop_loop:
    CIN_YES_NO play_from_record_stop_loop, HOME, main

play_from_record_stop_jmp_tbl:
    brtc PC + 2
    rjmp play_from_record_not_empty
    rjmp main


; ========================================================================================
; Menu > Settings menu
settings:
    clr var
    rcall LCD_clear
settings_loop:
    rcall LCD_home
    PRINTF LCD_putc
    .db CR, CR,  "Select :   ", LF, 0
    rcall LCD_lf
    
settings_loop_scales_text:
    cpi var, SETTINGS_MENU_SCALES
    brne settings_loop_duration_text

    PRINTF LCD_putc
    .db CR, CR, "<===  Scale ===> ", LF, 0
    rjmp settings_loop_end

settings_loop_duration_text:
    cpi var, SETTINGS_MENU_DURATION
    brne settings_loop_threshold_text

    PRINTF LCD_putc
    .db CR, CR, "<== Duration ==>", LF, 0
    rjmp settings_loop_end

settings_loop_threshold_text:
    cpi var, SETTINGS_MENU_THRESHOLD
    brne settings_loop_reset_text

    PRINTF LCD_putc
    .db CR, CR, "<=  Threshold =>", LF, 0
    rjmp settings_loop_end

settings_loop_reset_text:
    cpi var, SETTINGS_MENU_RESET

    PRINTF LCD_putc
    .db CR, CR, "<===  Reset ===>", LF,  0
    rjmp settings_loop_end

settings_loop_end:
    CIN_CYCLIC var, SETTINGS_MENU_SCALES, SETTINGS_MENU_RESET, settings_loop, HOME, main

settings_loop_jmp_tbl:
    cpi var, SETTINGS_MENU_SCALES
    brne PC+2
    rjmp settings_scales

    cpi var, SETTINGS_MENU_DURATION
    brne PC+2
    rjmp settings_duration

    cpi var, SETTINGS_MENU_THRESHOLD
    brne PC+2
    rjmp settings_threshold

    cpi var, SETTINGS_MENU_RESET
    brne PC+2
    rjmp settings_reset

    rjmp settings

; ========================================================================================
; Menu > Settings > Scales

settings_scales:
    EEPROM_READ scale_address, b0

    call LCD_clear
settings_scales_loop:
    call LCD_home
    PRINTF LCD_putc
    .db CR, CR, "Set scale : ", 0

setting_scales_DoM_text:
    cpi b0, DO_M
    brne setting_scales_ReM_text
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "Do Major ", 0
    rjmp setting_scales_loop_end
setting_scales_ReM_text:
    cpi b0, RE_M
    brne setting_scales_MiM_text
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "Re Major ", 0
    rjmp setting_scales_loop_end
setting_scales_MiM_text:
    cpi b0, MI_M
    brne setting_scales_SoM_text
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "Mi Major ", 0
    rjmp setting_scales_loop_end
setting_scales_SoM_text:
    cpi b0, SO_M
    brne setting_scales_LaM_text
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "Sol Major", 0
    rjmp setting_scales_loop_end
setting_scales_LaM_text:
    cpi b0, LA_M
    brne setting_scales_SiM_text
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "La Major ", 0
    rjmp setting_scales_loop_end
setting_scales_SiM_text:
    cpi b0, SI_M
    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, "Si Major ", 0
    rjmp setting_scales_loop_end

setting_scales_loop_end:
    CIN_CYCLIC b0, scales_tbl_index_min, scales_tbl_index_max, settings_scales_loop, HOME, main
    EEPROM_WRITE_REG scale_address, b0
    sts scale_address, b0

    rjmp main

; ========================================================================================
; Menu > Settings > Duration

settings_duration:
    EEPROM_READ duration_address, d0

    call LCD_clear
settings_duration_loop:
    call LCD_home
    PRINTF LCD_putc
    .db CR, CR, "Duration :", LF, 0

    call LCD_lf
    PRINTF LCD_putc
    .db CR, CR, FDEC|FDIG3, d, " x 25 ms", 0

    CIN_NUM d0, settings_duration_loop

    EEPROM_WRITE_REG duration_address, d0
    sts duration_address, d0

    rjmp main

; ========================================================================================
; Menu > Settings > Threshold
settings_threshold:
    EEPROM_READ threshold_address, d0

    call LCD_clear
settings_threshold_loop:
    PRINTF LCD_putc
    .db CR, CR, "Threshold :", FDEC|FDIG3, d, "   ", CR, 0

    ;CIN_NUM_CYC d0, 0, (analog_max_value + 1) / (notes_tbl_index_max+2), settings_threshold_loop
    CIN_NUM d0, settings_threshold_loop

    EEPROM_WRITE_REG threshold_address, d0
    sts threshold_address, d0

    rjmp main

; ========================================================================================
; Menu > Settings > Reset
settings_reset:
    call LCD_clear
    call LCD_home
    PRINTF LCD_putc
    .db CR, CR, "Reset? [Y/N]", 0
settings_reset_loop:
    CIN_YES_NO settings_reset_loop, HOME, main

settings_reset_jmp_tbl:
    brts PC + 2
    rjmp main

    EEPROM_WRITE scale_address, 0
    EEPROM_WRITE duration_address, 100
    EEPROM_WRITE threshold_address, 15

    STI scale_address, 0
    STI duration_address, 100
    STI threshold_address, 15

    call record_clear


    call  LCD_clear
    PRINTF LCD_putc
    .db CR, CR, "Resetted!", 0
    WAIT_MS 1000
    
    jmp main

    