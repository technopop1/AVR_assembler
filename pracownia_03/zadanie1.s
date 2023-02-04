.org 0x0000
	jmp start									; Reset handler
.org 0x0050
	jmp uart_tx_irq								; UART TX transfer complete

.include "include/atmega328p.s"
.include "include/macros.s"

.section .data

current_character_index:
	.space 2

current_beer_index:
	.space 2

tx_buffer:
	.space 64

.section .text

; Interrupt handlers

; UART TX transfer complete handler
uart_tx_irq:
	load_register_Y current_character_index
	load_register_Z tx_buffer

	; Load and Increment current character index
	ld r16, Y
	inc r16
	st Y, r16

	; Calculate pointer to the character
	clc
	add r30, r16
	ldi r16, 0x00
	adc r31, r16

	; Load current character
	ld r16, Z

	; Stop if current character is \x00
	tst r16
	breq uart_tx_irq_end

	; Send current character
	sts UDR0, r16
	reti

uart_tx_irq_end:
		
	load_register_Z current_beer_index
	ld r16, Z+									; dziesiatki
	ld r17, Z									; jednosci

	cpi r17, 0x31
	brne skip

	cpi r16, 0x30
	breq skip2

skip:	
	call send_next_text

skip2:
	reti

; Reset Interrupt handler
start:
	load_register_16 SPH, SPL, _stack_top

	ldi r16, 0x08
	sts UBRR0L, r16

	ldi r16, 0x48
	sts UCSR0B, r16

	ldi r16, 0x06
	sts UCSR0C, r16

	; Restart tx_buffer
	load_register_Z current_character_index
	ldi r16, 0x00
	st Z, r16

	; Restart beer counter
	load_register_Z current_beer_index
	ldi r16, 0x39
	st Z+, r16
	st Z, r16

	call send_next_text

	sei

sleep:
	sleep
	jmp sleep

; Copy Z to Y
copy_z_to_y:
	lpm r16, Z+									; load one byte from Z-reg on r16
	tst r16										; check if there is end of string - 0x00
	breq copy_z_to_y_end
	st Y+, r16
	rjmp copy_z_to_y
copy_z_to_y_end:
	ret

; Generating next text function
send_next_text:
	load_register_Y tx_buffer			

	; Insert tens number
	load_register_Z current_beer_index			
	ld r16, Z+									
	st Y+, r16

	; Insert ones number
	ld r17, Z									
	st Y+, r17

	; Copy text 
	load_register_Z text_00					
	call copy_z_to_y							

	; Insert tens number
	load_register_Z current_beer_index			
	ld r16, Z+														
	st Y+, r16

	; Insert ones number	
	ld r17, Z																
	st Y+, r17

	; Copy text
	load_register_Z text_01
	call copy_z_to_y

;------------------------------
	; Check if ones number is 0
	load_register_Z current_beer_index
	ld r16, Z+									; dziesiatki
	ld r17, Z									; jednosci

	cpi r17, 0x30
	brne go_here
	mov r19, r16
	dec r19
	st Y+, r19 
	mov r18, r17
	ldi r18, 0x39
	st Y+, r18
	rjmp send
go_here:
	;Insert tens number
	st Y+, r16
	; Insert ones number
	dec r17	
	st Y+, r17
send:
	; Copy text
	load_register_Z text_03
	call copy_z_to_y

	; Insert 0
	ldi r16, 0x00
	st Y+, r16

	; Restart tx_buffer
	load_register_Z current_character_index
	ldi r16, 0x00
	st Z+, r16
	st Z, r16

	; Decrement beer index
	load_register_Z current_beer_index
	ld r16, Z+
	ld r17, Z
	dec r17
	cpi r17, 0x30
	brne storage_data
	ldi r17, 0x39								; restore ones
	dec r16

storage_data:									; storage data for next loop
	st Z, r17
	st -Z, r16
	
	; Send first character
send_next_text_send_first:
	load_register_Y tx_buffer
	ld r16, Y
	sts UDR0, r16

send_next_text_end:
	ret

; Constants

text_00:
	.asciz " bottles of beer on the wall, "

text_01:
	.asciz " bottles of beer.\r\nTake one down and pass it around, "

text_03:
	.asciz " bottles of beer on the wall.\r\n\n\n"
