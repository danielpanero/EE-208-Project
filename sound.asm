; Piezoelectric library for sound
; in  period (r8)         period in 10 us unit
;     durationh:durationl (r11:r10)   duration of the note in 10us
; TODO remove scratch register using the stack
; TODO durationl:durationh should be read from the EEPROM

.def  period = r8
.def _period = r9 ; Scratch register (values are preserved via the stack)

.def  durationl = r10
.def  durationh = r11

sound_init:
  sbi	DDRE,SPEAKER ; Make pin SPEAKER an output
  ret

sound:
  push _period ; Saving values of the scratch register

  tst period ; Testing if 0 --> pause
  breq sound_off

sound_on:
  mov _period, period ; Copying into scratch register

sound_loop:
  WAIT_US 9
  ; 4 cycles = 1us
  dec period ; 1 cycles
  tst period ; 1 cycles
  brne sound_loop ; 2 cycles

  INVP  PORTE,SPEAKER

  sub durationl, period
  brsh PC+4 ; C = 0 (durationl > period)
  _subi durationh, 1 ; C = 1 (durationl < period)
  brcc PC+2 ; C = 0 (period - duration > 0)
  rjmp sound_restore_registers ; C=1 (period - duration < 0)

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
  pop _period
  ret

.equ	do	= 100000/523
.equ	dom	= 100000/554
.equ	re	= 100000/587
.equ	rem	= 100000/622
.equ	mi	= 100000/659
.equ	fa	= 100000/698
.equ	fam	= 100000/739
.equ	so	= 100000/783
.equ	som	= 100000/830
.equ	la	= 100000/880
.equ	lam	= 100000/923
.equ	si	= 100000/987

.equ	do2	= do/2
.equ	dom2	= dom/2
.equ	re2	= re/2
.equ	rem2	= rem/2
.equ	mi2	= mi/2
.equ	fa2	= fa/2
.equ	fam2	= fam/2
.equ	so2	= so/2
.equ	som2	= som/2
.equ	la2	= la/2
.equ	lam2	= lam/2
.equ	si2	= si/2

.equ	do3	= do/4
.equ	dom3	= dom/4
.equ	re3	= re/4
.equ	rem3	= rem/4
.equ	mi3	= mi/4
.equ	fa3	= fa/4
.equ	fam3	= fam/4
.equ	so3	= so/4
.equ	som3	= som/4
.equ	la3	= la/4
.equ	lam3	= lam/4
.equ	si3	= si/4


.equ notes_tbl_index_min = 0
.equ notes_tbl_index_max = 7
.cseg
notes_tbl: .db do, re, mi, fa, so, la, si, do2