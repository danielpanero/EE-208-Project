; I2C library for EEPROM
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


; TODO change order of parameters to standard reg, address and not address, reg
.macro EEPROM_READ
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_rep_start,EEPROM + R

    rcall i2c_read
    mov @1, a0

    rcall i2c_no_ack
	rcall i2c_stop

.endmacro 

.macro EEPROM_WRITE
    CA i2c_start, EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_write, @1
    rcall i2c_stop
.endmacro

.macro EEPROM_WRITE_REG
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    mov a0, @1
    rcall i2c_write
    rcall i2c_stop
.endmacro