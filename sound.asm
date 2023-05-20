; Piezoelectric library for sound
; in  periodh:periodl (r9:r8)         period in 10 us unit
;     durationh:durationl (r11:r10)   duration of the note in 10us

.def  periodl = r18
.def  periodh = r19

.def _periodl = r22
.def _periodh = r23

.def  durationl = r20
.def  durationh = r21

sound_init:
  sbi	DDRE,SPEAKER ; Make pin SPEAKER an output
  ret

sound:
; in  periodh:periodl (r9:r8)         period in 10 us unit
;     durationh:durationl (r11:r10)   duration of the note in 10us
  TST2 periodh, periodl ; Testing if 0 --> pause
  breq sound_off

sound_on:
  MOV2 _periodh, _periodl, periodh, periodl ; Copying into scratch registers
  ;LSR2 _periodh, _periodl ; Divide by two to adjust ON/OFF period 

sound_loop:
  WAIT_US 8
  ; 8 cycles = 2us
  DEC2 _periodh, _periodl ; 3 cycles
  TST2 _periodh, _periodl ; 3 cycles
  brne sound_loop ; 2 cycles

  INVP  PORTE,SPEAKER

  CP2 durationh, durationl, periodh, periodl
  brcc PC+2
  ret ; C=1 (period - duration < 0)
  brne PC+2
  ret ; Z=1 (period - duration = 0)

  SUB2 durationh, durationl, periodh, periodl ; (period - duration >= 0)
  rjmp sound_on 

sound_off:
  WAIT_US 8
  ; 8 cacles = 2 us
  DEC2 durationh, durationl ; 3 cycles
  TST2 durationh, durationl ; 3 cycles
  brne sound_off ; 2 cycles
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

.cseg
notes_tbl: .db do, dom, re, rem, mi, fa, fam, so, som, la, lam, si, do2, dom2, re2, rem2, mi2, fa2, fam2, so2, som2, la2, lam2, si2