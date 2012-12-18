
	.include "vcregs.inc"

	.macro poke reg, val
		mov r1, \reg
		mov r0, \val
		st r0, (r1)
	.endm

	.macro peek dest, reg
		mov \dest, \reg
		ld \dest, (\dest)
	.endm

	.text

	/**
	 * Waits for some cycles, the cycle count is passed in r0.
	 */
	.global delay
delay:
	mov r1, 0
L_delay_loop:
	add r1, 1
	cmp r1, r0
	bne L_delay_loop
	rts

	.global initialize_clocks
initialize_clocks:
	/* TODO */
	rts

	/**
	 * Initializes the clocks for use with the mini uart and the OK led.
	 */
	.global initialize_gpio
initialize_gpio:
	push r6, lr
	/* configure TX and RX GPIO pins for Mini Uart function. */
	mov r1, VC_GPIO_FSEL1
	ld r0, (r1)
	and r0, ~(7<<12)
	or r0, 2<<12
	and r0, ~(7<<15)
	or r0, 2<<15
	/* configure LED pin */
	and r0, ~(7<<18)
	or r0, 1<<18
	st r0, (r1)

	mov r1, VC_GPIO_PUD
	mov r0, 0
	st r0, (r1)

	mov r0, 150
	bl delay

	mov r1, VC_GPIO_PUDCLK0
	mov r0, 1<<14|1<<15
	st r0, (r1)

	mov r0, 150
	bl delay

	mov r1, VC_GPIO_PUDCLK0
	mov r0, 0
	st r0, (r1);

	/* set up serial port */
	poke VC_AUX_ENABLES, 1
	poke VC_AUX_MU_IER_REG, 0
	poke VC_AUX_MU_CNTL_REG, 0
	poke VC_AUX_MU_LCR_REG, 3
	poke VC_AUX_MU_MCR_REG, 0
	poke VC_AUX_MU_IER_REG, 0
	poke VC_AUX_MU_IIR_REG, 0xc6
	bl set_uart_speed
	poke VC_AUX_MU_LCR_REG, 0x03
	poke VC_AUX_MU_CNTL_REG, 3

	pop r6, pc

	.global set_led_on
set_led_on:
	mov r0, VC_GPIO_CLR0
	mov r1, 1<<16
	st r1, (r0)
	rts

	.global set_led_off
set_led_off:
	mov r0, VC_GPIO_SET0
	mov r1, 1<<16
	st r1, (r0)
	rts

	.global set_uart_speed
set_uart_speed:
	/* TODO */
	.equ BAUD_REG, ((19200000/(115200*8))-1)
	poke VC_AUX_MU_BAUD_REG, BAUD_REG
	rts

	.global uart_recv_int
uart_recv_int:
	push r6, lr
	bl uart_recv_byte
	mov r6, r0
	bl uart_recv_byte
	lsl r6, 8
	or r6, r0
	bl uart_recv_byte
	lsl r6, 8
	or r6, r0
	bl uart_recv_byte
	lsl r6, 8
	or r0, r6
	pop r6, pc

	.global uart_recv_byte
uart_recv_byte:
	push r6-r7, lr
	mov r7, 0
	mov r6, 0
L_uart_recv_byte_loop:
	/* read one digit */
	bl uart_recv_char
	/* and convert it from hex */
	cmp r0, '0'
	blt L_uart_recv_byte_end
	cmp r0, '9'
	bgt L_uart_recv_byte_alpha
	sub r0, '0'
	b L_uart_recv_byte_conv_done
L_uart_recv_byte_alpha:
	cmp r0, 'a'
	blt L_uart_recv_byte_uppercase
	sub r0, 'a' - 'A'
L_uart_recv_byte_uppercase:
	cmp r0, 'A'
	blt L_uart_recv_byte_end
	cmp r0, 'F'
	bgt L_uart_recv_byte_end
	sub r0, 'A' - 10

	/* add the digit to the result */
L_uart_recv_byte_conv_done:
	lsl r6, 4
	or r6, r0

	add r7, 1
	cmp r7, 2
	bne L_uart_recv_byte_loop
	/* return the composed number */
L_uart_recv_byte_end:
	mov r0, r6
	pop r6-r7, pc

	.global uart_recv_char
uart_recv_char:
    /* wait until a char arrived in the fifo */
    mov r0, VC_AUX_MU_LSR_REG
    ld r0, (r0)
    and r0, 0x1
    cmp r0, 0x1
    bne uart_recv_char
    /* read the char */
    mov r0, VC_AUX_MU_IO_REG
    ld r0, (r0)
	rts

	.global uart_send_str
uart_send_str:
	push r6, lr
	mov r6, r0
L_uart_send_str_loop:
	ldb r0, (r6)
	cmp r0, 0
	beq L_uart_send_str_loop_end
	bl uart_send_char
	add r6, 1
	b L_uart_send_str_loop
L_uart_send_str_loop_end:
	pop r6, pc

	.global uart_send_int
uart_send_int:
	push r6, lr
	mov r6, r0
	lsr r0, 24
	bl uart_send_byte
	mov r0, r6
	lsr r0, 16
	bl uart_send_byte
	mov r0, r6
	lsr r0, 8
	bl uart_send_byte
	mov r0, r6
	bl uart_send_byte
	pop r6, pc

	.global uart_send_byte
uart_send_byte:
	push r6, lr
	mov r6, r0
	lsr r0, 4
	and r0, 0xf
	lea r1, uart_hex_digits
	add r0, r1
	ldb r0, (r0)
	bl uart_send_char
	mov r0, r6
	and r0, 0xf
	lea r1, uart_hex_digits
	add r0, r1
	ldb r0, (r0)
	bl uart_send_char
	pop r6, pc

	.global uart_send_char
uart_send_char:
    mov r1, VC_AUX_MU_LSR_REG
    ld r1, (r1)
    /*and r1, 0x20
    cmp r1, 0x20
    bne uart_send_char*/
    btst r1, 5
    beq uart_send_char
    mov r1, VC_AUX_MU_IO_REG
    st r0, (r1)
	rts

	.global uart_flush
uart_flush:
    mov r0, VC_AUX_MU_LSR_REG
L_uart_flush_loop:
    ld r1, (r0)
    btst r1, 6
    beq L_uart_flush_loop
	rts
	

uart_hex_digits:
	.ascii "0123456789abcdef"
