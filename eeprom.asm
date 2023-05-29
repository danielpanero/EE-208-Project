; file:	eeprom.asm   target ATmega128L-4MHz-STK300
; I2C library for EEPROM
; Copyright 2023: Daniel Panero (342800), Yasmina Jemili (310507)

.equ	EEPROM	= 0b10100000	; device address
.equ	R	= 1					; read flag


eeprom_init:
    OUTI DDRB,0xff
    OUTI PORTB,0xff

    in	r16, SFIOR ; Disabling internal pull-up
	ori	r16, (1<<PUD)
	out	SFIOR, r16
	rcall i2c_init
    ret	

.macro EEPROM_READ
    WAIT_US 2000
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_rep_start,EEPROM + R

    call i2c_read
    mov @1, a0

    call i2c_no_ack
	call i2c_stop
    WAIT_US 2000

.endmacro 

.macro EEPROM_WRITE
    WAIT_US 2000
    CA i2c_start, EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_write, @1
    call i2c_stop
    WAIT_US 1000
.endmacro

.macro EEPROM_WRITE_REG
    WAIT_US 2000
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    mov a0, @1
    call i2c_write
    call i2c_stop
    WAIT_US 2000
.endmacro