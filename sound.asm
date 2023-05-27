; Piezoelectric library for sound
; TODO recalibrate frequencies
; TODO finish scales
; TODO PUSH, POP using macros

; Scratch registers (values are preserved via the stack):
.def period = r22 
.def durationl = r23
.def durationh = r24
.def scale_index = r25

.dseg
duration_address: .byte 1
scale_address: .byte 1

.cseg
sound_init:
    sbi	DDRE,SPEAKER ; Make pin SPEAKER an output

    push durationh
    push scale_index

    EEPROM_READ duration_address, durationh
    sts duration_address, durationh

    EEPROM_READ scale_address, scale_index
    sts scale_address, scale_index

    ;DBREGF "Scale index": , FDEC, scale_index

    pop scale_index
    pop durationh
    ret


; Plays a note selected using scale selection and the index of note (preloaded)
sound_play_note:
    push period ; Saving values of the scratch registers
    push durationl
    push durationh
    push scale_index

    lds scale_index, scale_address
    LDIZ 2*(notes_tbl)

sound_scale_load: ; Since there eight notes in a scale, it multiplies the pointer by 8 to find the next scale
    tst scale_index
    breq sound_note_load ; If the selected scale is Do Major, it directly goes to loading the note
    adiw zh:zl, 8
    DJNZ scale_index, sound_scale_load

sound_note_load: ; Going through the notes_tbl: note_index = 0 --> lowest note, note_index = 6 --> highest note:
    ADDZ note_index

    lpm
    mov period, r0

    ;DBREGF "Note index: ", FDEC, note_index
    ;DBREGF "Period: ", FDEC, period

sound:
    clr durationl
    lds durationh, duration_address

    tst period ; If period equals 0, no sound
    brne PC+2
    rjmp sound_off

sound_on:
    push period ; Saving period before modifying it

sound_loop:
    WAIT_US 9
    ; 4 cycles = 1us
    dec period ; 1 cycles
    tst period ; 1 cycles
    brne sound_loop ; 2 cycles

    INVP  PORTE,SPEAKER

    pop period ; Restoring initial value of period
    sub durationl, period
    brsh PC+2 ; C = 0 (durationl > period)
    subi durationh, 1 ; C = 1 (durationl < period)
    brcc PC+2 ; C = 0 (period - duration > 0)
    rjmp sound_restore_registers ; C=1 (period - duration < 0)

    ;DBREGSF "Duration left", FDEC2, durationh, durationl

    tst durationh 
    brne PC+2 ; Z= 0 (period > 0)
    rjmp sound_restore_registers; Z=1 (period - duration = 0)

    rjmp sound_on 

sound_off:
    WAIT_US 8
    ; 8 cacles = 2 us
    DEC2 durationh, durationl ; 3 cycles
    TST2 durationh, durationl ; 3 cycles
    brne sound_off ; 2 cycles

    rjmp sound_restore_registers

sound_restore_registers:
    pop scale_index
    pop durationh
    pop durationl
    pop period
    ret


.equ	do	= 100000/523
.equ	dod	= 100000/554
.equ	reb	= 100000/554
.equ	re	= 100000/587
.equ	red	= 100000/622
.equ	mib	= 100000/622
.equ	mi	= 100000/659
.equ	fa	= 100000/698
.equ	fad	= 100000/739
.equ	sob	= 100000/739
.equ	so	= 100000/783
.equ	sod	= 100000/830
.equ	lab	= 100000/880
.equ	la	= 100000/880
.equ	lad	= 100000/923
.equ	sib	= 100000/923
.equ	si	= 100000/987

.equ	do2	= do/2
.equ	dod2	= dod/2
.equ	reb2	= reb/2
.equ	re2	= re/2
.equ	red2	= red/2
.equ	mib2	= mib/2
.equ	mi2	= mi/2
.equ	fa2	= fa/2
.equ	fad2	= fad/2
.equ	sob2	= sob/2
.equ	so2	= so/2
.equ	sod2	= sod/2
.equ	lab2	= lab/2
.equ	la2	= la/2
.equ	lad2	= lad/2
.equ	sib2	= sib/2
.equ	si2	= si/2


.equ scales_tbl_index_min = 0
.equ scales_tbl_index_max = 3

.equ notes_tbl_index_min = 0
.equ notes_tbl_index_max = 7

.cseg
notes_tbl: .db do, re, mi, fa, so, la, si, do2, ; Do Major
 .db so, la, si, do2, re2, mi2, fad2, so2, ; Sol Major
 .db re, mi, fad, so, la, si, dod2, re2, ; Re Major
 .db la, si, dod2, re2, mi2, fad2, sod2, la2, ; La Major