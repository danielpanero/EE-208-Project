; Analog deconding library for SHARP GPS2Y0A21
; TODO Change from analog_service_rountine into free running mode and remove need for analog_flag
; TODO Clean up and organize it

; Global variables:
.def analog_flag = r20 ; FIXME remove it

; Scratch registers (values are preserved via the stack):
.def analog_threshold = r17
.def analogl = r18
.def analogh = r19

.equ ANLFINISHED = 0
.equ ANLREQUESTED = 1

.equ analog_max_value = 1023

.dseg
threshold_address: .byte 1

.cseg

; FIXME add saving sreg 
analog_service_routine:
	ldi	analog_flag, (1<<ANLFINISHED) + (1<<ANLREQUESTED) ; Set the flag	
	reti 

analog_init:
    OUTI ADCSR,(1<<ADEN) + (1<<ADIE) + 6 ; AD Enable, AD int. enable, PS=CK/64	
	OUTI ADMUX, 3 ; Select channel for SHARP GPS2Y0A21

    clr analog_flag

    push analog_threshold

    EEPROM_READ threshold_address, analog_threshold
    sts threshold_address, analog_threshold

    pop analog_threshold

    ret
analog_loop:
    ;DBMSG "Analog conversion was requested"
    ;DBREG "Analog flag before: ", analog_flag
    ;DBIO "The ADCSR register: ", ADCSR
    sei
    
    CB0 analog_flag, ANLREQUESTED, analog_start ; If it wasn't already requested, it fires a new conversion

    RB0 analog_flag, ANLFINISHED ; Return if the analog requested is still pending

    push analogl 
    push analogh

    in	analogl, ADCL
	in	analogh, ADCH

    ldi analog_flag, (0<<ANLFINISHED) + (1<<ANLREQUESTED)
    sbi	ADCSR,ADSC

    ;DBREGS "Analog conversion is being treated: ", analogh, analogl
    SUBI2 analogh, analogl, 1023 ; Subtract maximal value
    NEG2 analogh, analogl	

    rcall analog_normalize_note_index

    pop analogh
    pop analogl
    ret

analog_start:
    ;DBMSG "Analog conversion wasn't already started nor pending"
    ldi analog_flag, (0<<ANLFINISHED) + (1<<ANLREQUESTED)
    ;DBREG "Analog was set to: ", analog_flag
    sbi	ADCSR,ADSC
    ;DBIO "The ADCSR register: ", ADCSR
    ret

; a1:a0 = analogh:analogl, b0 = (analog_max_value + 1) / (notes_tbl_index_max+2), c1:c0 = a1:a0 / b0 (integer division), d0 = a1:a0 % b0 (rest), d1 = c0 - note_index
analog_normalize_note_index:
    PUSH5 a1, a0, b0, c1, c0, d0, d1, analog_threshold

    MOV2 a1, a0, analogh, analogl
    ldi b0, (analog_max_value + 1) / (notes_tbl_index_max+2)

    rcall div21

    ; Normalizing c0 into [0,7]
    _cpi c0, notes_tbl_index_min ; note_index must be >= 0
    brsh PC+3 
    _ldi c0, notes_tbl_index_min

    _cpi c0, notes_tbl_index_max ; note_index must be <= 7
    brlo PC+3
    _ldi c0, notes_tbl_index_max

    mov d1, c0
    sub d1, note_index

    ; Calculating the absolute value of d1
    tst d1
    brpl PC+2
    neg d1

    _cpi d1, 1
    breq PC + 2 ; If c0 - note_index = 1, we have to check if the rest is bigger than 25% of (analog_max_value + 1) / (notes_tbl_index_max+2)
    rjmp analog_finalize_note_index

    ;DBMSG "Checking"

    lds analog_threshold, threshold_address
    cp d0, analog_threshold

    ;DBREGF "Rest :", FDEC, d0
    ;DBSREG "SREG"
    
    brsh PC+2 ; If the d0 < 25% of (analog_max_value + 1) / (notes_tbl_index_max+2), we don't change the note
    rjmp analog_restore_registers

    
analog_finalize_note_index:
    mov note_index, c0

    cpi note_index, notes_tbl_index_min ; note_index must be >= 0
    brsh PC+2 
    ldi note_index, notes_tbl_index_min

    cpi note_index, notes_tbl_index_max + 1 ; note_index must be <= 7
    brlo PC+2
    ldi note_index, notes_tbl_index_max


analog_restore_registers:
    POP5 a1, a0, b0, c1, c0, d0, d1, analog_threshold
    ret