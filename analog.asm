; Analog deconding library for SHARP GPS2Y0A21

.def analogl = r22
.def analogh = r23
.def analog_flag = r24

.equ ANLFINISHED = 0
.equ ANLREQUESTED = 1

analog_service_routine:
	ldi	analog_flag, (1<<ANLFINISHED) + (1<<ANLREQUESTED) ; Set the flag	
	reti 

analog_init:
    OUTI ADCSR,(1<<ADEN) + (1<<ADIE) + 6 ; AD Enable, AD int. enable, PS=CK/64	
	OUTI ADMUX, 3 ; Select channel for SHARP GPS2Y0A21

    clr analog_flag

    ret
analog_loop:
    DBMSG "Analog conversion was requested"
    DBREG "Analog flag before: ", analog_flag
    DBIO "The ADCSR register: ", ADCSR
    CB0 analog_flag, ANLREQUESTED, analog_start ; If it wasn't already requested, it fires a new conversion

    RB0 analog_flag, ANLFINISHED ; Return if the analog requested is still pending

    in	analogl, ADCL
	in	analogh, ADCH

    DBREGS "Analog conversion is being treated: ", analogh, analogl
    SUBI2 analogh, analogl, 1023 ; Subtract maximal value
    NEG2 analogh, analogl	

    ldi analog_flag, (0<<ANLFINISHED) + (1<<ANLREQUESTED)
    sbi	ADCSR,ADSC
    DBIO "The ADCSR register: ", ADCSR

    ret

analog_start:
    DBMSG "Analog conversion wasn't already started nor pending"
    ldi analog_flag, (0<<ANLFINISHED) + (1<<ANLREQUESTED)
    DBREG "Analog was set to: ", analog_flag

    sbi	ADCSR,ADSC
    DBIO "The ADCSR register: ", ADCSR
    ret


