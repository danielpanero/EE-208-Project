; Analog deconding library for SHARP GPS2Y0A21
; TODO Change from analog_service_rountine into free running mode and remove need for analog_flag

; Global variables:
.def analog_flag = r20 ; FIXME remove it

; Scratch registers (values are preserved via the stack):
.def analogl = r18
.def analogh = r19

.equ ANLFINISHED = 0
.equ ANLREQUESTED = 1

.equ analog_max_value = 1023

analog_service_routine:
	ldi	analog_flag, (1<<ANLFINISHED) + (1<<ANLREQUESTED) ; Set the flag	
	reti 

analog_init:
    OUTI ADCSR,(1<<ADEN) + (1<<ADIE) + 6 ; AD Enable, AD int. enable, PS=CK/64	
	OUTI ADMUX, 3 ; Select channel for SHARP GPS2Y0A21

    clr analog_flag

    ret
analog_loop:
    ;DBMSG "Analog conversion was requested"
    ;DBREG "Analog flag before: ", analog_flag
    ;DBIO "The ADCSR register: ", ADCSR
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

    clr note_index
    rcall analog_loop_normalize_note_index

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

; TODO better transition between notes / more stable transition (increasing the length of the note / adding 10% margin before switching)
analog_loop_normalize_note_index:
    inc note_index

    ;DBREGSF "Analog: ", FDEC2, analogh, analogl
    SUBI2 analogh, analogl, analog_max_value / (notes_tbl_index_max+2)  ; We choosed to place a note every 40 dec
    ;DBSREG "SREG: "
    JC0 analog_loop_normalize_note_index ; If analogh:analog_loop > 40, we can still make an higher note

    dec note_index

    cpi note_index, notes_tbl_index_min ; note_index must be >= 0
    brsh PC+2 
    ldi note_index, notes_tbl_index_min

    cpi note_index, notes_tbl_index_max + 1 ; note_index must be <= 23
    brlo PC+2
    ldi note_index, notes_tbl_index_max

    ;DBREGF "Final note found was: ", FDEC, note_index
    ret

