; Piezoelectric library for sound
; in  period (r8)         period in 10 us unit
; TODO remove scratch register using the stack
; TODO durationl:durationh should be read from the EEPROM
; TODO recalibrate frequencies
; TODO finish writing scales and subroutine to point to the right scale

.def  period = r8
.def _period = r9 ; Scratch register (values are preserved via the stack)

.def  durationl = r23
.def  durationh = r24

sound_init:
  sbi	DDRE,SPEAKER ; Make pin SPEAKER an output
  ret

sound:
  push _period ; Saving values of the scratch register
  push durationl
  push durationh

  ldi durationl, low(50000)
  ldi durationh, high(50000)

  tst period ; Testing if 0 --> pause
  brne PC+2
  rjmp sound_off

sound_on:
  mov _period, period ; Copying into scratch register

sound_loop:
  WAIT_US 9
  ; 4 cycles = 1us
  dec _period ; 1 cycles
  tst _period ; 1 cycles
  brne sound_loop ; 2 cycles

  INVP  PORTE,SPEAKER

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
  pop durationh
  pop durationl
  pop _period
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


.equ notes_tbl_index_min = 0
.equ notes_tbl_index_max = 7
.cseg
notes_tbl_do: .db do, re, mi, fa, so, la, si, do2
notes_tbl_so: .db so, la, si, do2, re2, mi2, fad2, so2
notes_tbl_re: .db re, mi, fad, so, la, si, dod2, re2
notes_tbl_la: .db la, si, dod2, re2, mi2, fad2, sod2, la2

.equ scales_tbl_index_min = 0
.equ scales_tbl_index_max = 3
scales_tbl: .dw notes_tbl_do, notes_tbl_so, notes_tbl_re, notes_tbl_la
