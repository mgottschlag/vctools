
	.include "vcregs.inc"

	.macro poke reg, val
		mov r1, \reg
		mov r0, \val
		st r0, (r1)
	.endm

	.macro check reg, val
		mov r1, \reg
1:
		ld r0, (r1)
		mov r2, \val
		bne r0, r2, 1b
	.endm

	.global _start
_start:
	/* mov sp, 0x60008800 */

	poke VC_SDCO__ADDRESS + 0x0, 0x00218e4a
	#poke VC_SDCO__ADDRESS + 0x0, 0x00214e4a
	#poke VC_CM__ADDRESS + 0x1a8, 0x00000091
	poke VC_CM__ADDRESS + 0x1a8, 0x5a020091
	#poke VC_CM__ADDRESS + 0x1a8, 0x00030091
	poke VC_CM__ADDRESS + 0x1a8, 0x5a028081
	poke VC_CM__ADDRESS + 0x1a8, 0x5a008081
	#poke VC_CM__ADDRESS + 0x1a8, 0x00008001
	poke VC_UNKe06000__ADDRESS + 0x58, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x24, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x28, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x2c, 0x00010053
	poke VC_UNKe06000__ADDRESS + 0x30, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x34, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x24, 0x00000001
	#poke VC_UNKe06000__ADDRESS + 0x48, 0x00010000
	poke VC_UNKe06000__ADDRESS + 0x28, 0x00000001
	#poke VC_CM__ADDRESS + 0x1a8, 0x00008001
	poke VC_CM__ADDRESS + 0x1a8, 0x5a028001
	#poke VC_CM__ADDRESS + 0x1a8, 0x00038001
	poke VC_CM__ADDRESS + 0x1a8, 0x5a024001
	poke VC_CM__ADDRESS + 0x1a8, 0x5a004001
	#poke VC_CM__ADDRESS + 0x1a8, 0x00004001
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000030
	poke VC_DCRC__ADDRESS + 0x4, 0x00000001
	poke VC_UNKe06000__ADDRESS + 0x4, 0x00000001
	#poke VC_SDCO__ADDRESS + 0x0, 0x0021424a
	poke VC_DCRC__ADDRESS + 0x4, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x4, 0x00000000
	poke VC_SDCO__ADDRESS + 0x4, 0x0c293395
	poke VC_SDCO__ADDRESS + 0x8, 0x000000f9
	poke VC_SDCO__ADDRESS + 0xc, 0x32200743
	poke VC_SDCO__ADDRESS + 0x94, 0x71810f66
	poke VC_SDCO__ADDRESS + 0x98, 0x10412136
	poke VC_SDCO__ADDRESS + 0x14, 0x0137b828
	poke VC_SDCO__ADDRESS + 0x10, 0x00000f96
	poke VC_SDCO__ADDRESS + 0x64, 0x00000003
	#poke VC_DCRC__ADDRESS + 0x18, 0x0000ffff
	#poke VC_UNKe06000__ADDRESS + 0x20, 0x00000003
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000000
	poke VC_SDCO__ADDRESS + 0x0, 0x00200043

	check VC_L1CC__ADDRESS + 0x0, 0x00000000
	poke VC_L1CC__ADDRESS + 0x0, 0x00000002
	check VC_L1CC__ADDRESS + 0x0, 0x00000000
	check VC_L1CC__ADDRESS + 0x100, 0x0000000
	poke VC_L1CC__ADDRESS + 0x104, 0x00000000
	poke VC_L1CC__ADDRESS + 0x108, 0x3fffffff
	poke VC_L1CC__ADDRESS + 0x100, 0x00000006
	check VC_L1CC__ADDRESS + 0x100, 0x00000000
	check VC_L1CC__ADDRESS + 0x100, 0x00000000
	check VC_L2CC__ADDRESS + 0x0, 0x00000000
	poke VC_L2CC__ADDRESS + 0x4, 0x00000000
	poke VC_L2CC__ADDRESS + 0x8, 0x0fffffe0
	poke VC_L2CC__ADDRESS + 0x0, 0x00000014
	check VC_L2CC__ADDRESS + 0x0, 0x00000010
	check VC_L1CC__ADDRESS + 0x0, 0x00000000
	poke VC_L1CC__ADDRESS + 0x8, 0x00000000
	poke VC_L1CC__ADDRESS + 0xc, 0x3fffffff
	poke VC_L1CC__ADDRESS + 0x0, 0x00000002
	check VC_L1CC__ADDRESS + 0x0, 0x00000000

	lea r0, boot_string
	bl uart_send_str

	/* read the size of the image */
	bl uart_recv_int
	mov r7, r0

	/* read the image itself */
	mov r6, 0x84000000
	add r7, r6
read_loop:
	bl uart_recv_byte
	stb r0, (r6)

	add r6, 1
	cmp r6, r7
	bne read_loop

	/* branch into the code */
	mov r6, 0x84000000
	bl r6

end:
	b end

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
    and r1, 0x20
    cmp r1, 0x20
    bne uart_send_char
    mov r1, VC_AUX_MU_IO_REG
    st r0, (r1)
	rts

uart_flush:
    mov r0, VC_AUX_MU_LSR_REG
L_uart_flush_loop:
    ld r1, (r0)
    btst r1, 6
    beq L_uart_flush_loop
	rts

uart_hex_digits:
	.ascii "0123456789abcdef"

boot_string:
	.ascii "bootloader\r\n\0"

newline:
	.ascii "\r\n\0"

