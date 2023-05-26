; I2C library for EEPROM
.equ	EEPROM	= 0b10100000	; device address
.equ	R	= 1					; read flag


; TODO at first start check whether some flag is initialized and if not initialize default settings
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
    WAIT_US 2000
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_rep_start,EEPROM + R

    rcall i2c_read
    mov @1, a0

    rcall i2c_no_ack
	rcall i2c_stop
    WAIT_US 2000

.endmacro 

.macro EEPROM_WRITE
    WAIT_US 2000
    CA i2c_start, EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    CA i2c_write, @1
    rcall i2c_stop
    WAIT_US 1000
.endmacro

.macro EEPROM_WRITE_REG
    WAIT_US 2000
    CA i2c_start,EEPROM
    CA i2c_write, high(@0)
	CA i2c_write, low(@0)

    mov a0, @1
    rcall i2c_write
    rcall i2c_stop
    WAIT_US 2000
.endmacro