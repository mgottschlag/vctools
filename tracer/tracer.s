
/*
This file implements a memory access tracer which is run on the videocore.
It only emulates the instructions which cannot be executed directly. It is
placed at 0x84000000 by its bootloader and then reads the bootcode via the uart
and starts to execute it at 0x80000200. It dumps memory accesses and interrupts
via the uart.
*/

	.include "vcregs.inc"

	.equ BACKUP_SIZE, 8

	.text
	.global _start
_start:
	/* the stack starts just below the tracer executable */
	mov sp, 0x84000000
	mov r28, r0, sp

	/* the executable has been appended to the tracer */
	ld r2, tracer_end
	lea r0, tracer_end
	add r0, 4
	mov r1, 0x80000000
	bl memcpy

	/* install interrupt handlers */
	lea r0, tracer_end
	add r1, r0, 0x200
install_handler_loop:
	lea r2, interrupt_handler
	st r2, (r0)
	add r0, 4
	bne r0, r1, install_handler_loop

	lea r0, tracer_end
	add r1, r0, 248
	lea r2, first_breakpoint_handler
	st r2, (r1)
	add r1, r0, 252
	lea r2, second_breakpoint_handler
	st r2, (r1)
	mov r1, 0x7e002030
	st r0, (r1)

	/* start executing the code */
	lea r0, tracer_starting
	bl uart_send_str
	
	mov r0, 0x80000200
	lea r1, first_instruction
	bl add_first_breakpoint

	mov r0, 0x80000200
	b r0

first_instruction:
	bl process_instruction

process_instruction:
	/*mov r0, r0, r25
	bl uart_send_int*/
	/*lea r0, newline
	bl uart_send_str*/
	/* print the address of the next instruction */
	/*lea r0, tracer_pc_label
	bl uart_send_str
	mov r0, r14
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/
	/* determine the instruction length */
	ldh r13, (r14)
	/*mov r0, r13
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/
	btst r13, 15
	beq process_scalar16
	btst r13, 14
	beq process_scalar32
	btst r13, 13
	beq process_scalar32
	btst r13, 12
	beq process_scalar48
	btst r13, 11
	beq process_vector48
	b process_vector80

process_scalar16:
	mov r12, 2

	cmp r13, 0x4000
	bge next_instruction
	cmp r13, 0x000a /* rti */
	beq process_scalar16_rti
	cmp r13, 0x40 /* lots of unknowns, but no known branch */
	blt next_instruction
	cmp r13, 0x00c0
	blt process_scalar16_b_bl_tbx
	/* TODO: the following includes pop/push which might include/modify r28 */
	cmp r13, 0x0300
	blt next_instruction
	btst r13, 13
	bne process_scalar16_ld_st
	cmp r13, 0x1800
	bge process_scalar16_bcc
	btst r13, 11
	bne process_scalar16_ld_st_2
	btst r13, 7 /* push */
	bne next_instruction
	/* here, the instruction is a pop >= 0x0300 and <0x400 ("pop x-y, pc") */
	/* TODO */
	b panic

process_scalar16_rti:
	/* TODO */
	b panic

process_scalar16_b_bl_tbx:
	/* TODO */
	b panic

process_scalar16_ld_st:
	beq r14, r15, process_scalar16_ld_st_cont
	/* execute all previous instructions, then execute the load/store */
	mov r0, r14
	lea r1, process_scalar16_ld_st_cont
	bl add_first_breakpoint
	b execute

process_scalar16_ld_st_cont:
	ldh r13, (r14)
	/* compute the address */
	lsr r0, r13, 4
	and r0, 0xf
	bl read_register
	lsr r1, r13, 6
	and r1, 0x3c
	add r0, r1
	/* destination/source register */
	and r1, r13, 0xf
	/* execute the load/store */
	btst r13, 12
	beq 1f
	bl emulate_store
	b 2f
1:
	bl emulate_load
2:
	add r15, 2
	add r14, 2
	b process_instruction

process_scalar16_bcc:
	/* compute the branch target */
	exts r6, r13, 6
	beq r6, 1, next_instruction /* check that the breakpoints do not overlap */
	lsl r6, 1
	add r6, r14
	/* if the branch is within the current instructions, it can be executed */
	blt r6, r15, scalar16_bcc_needs_to_be_emulated
	add r0, r6, 2
	bgt r0, r14, scalar16_bcc_needs_to_be_emulated
	mov r12, 2
	b next_instruction
scalar16_bcc_needs_to_be_emulated:
	st r6, branch_target
	bl save_instruction
	/* modify the instruction to hit one of the two breakpoints */
	and r13, 0xff80
	add r13, 2
	sth r13, (r14)
	/* add two breakpoints and execute the instruction */
	add r0, r14, 2
	lea r1, branch_not_taken
	bl add_first_breakpoint
	add r0, r14, 4
	lea r1, branch_taken
	bl add_second_breakpoint
	b execute

process_scalar16_ld_st_2:
	beq r14, r15, process_scalar16_ld_st_2_cont
	/* execute all previous instructions, then execute the load/store */
	mov r0, r14
	lea r1, process_scalar16_ld_st_2_cont
	bl add_first_breakpoint
	b execute

process_scalar16_ld_st_2_cont:
	ldh r13, (r14)
	/* TODO */
	mov r12, 2
	b next_instruction

	/* compute the address */
	lsr r0, r13, 4
	and r0, 0xf
	bl read_register
	/* destination/source register */
	and r1, r13, 0xf
	/* execute the load/store */
	mov r2, r13
	and r2, 0x0600
	bne r2, 0, panic

	btst r13, 8
	beq 1f
	bl emulate_store
	b 2f
1:
	bl emulate_load
2:
	add r15, 2
	add r14, 2
	b process_instruction

process_scalar32:
	mov r12, 4
	/* TODO: the following might modify r28 */
	cmp r13, 0xb000
	bge next_instruction
	/* everything below will be emulated, so save the instruction */
	/*bl scalar32_save*/
	cmp r13, 0x9000
	blt process_scalar32_addcmpbcc
	cmp r13, 0xa000
	blt process_scalar32_b_bl
	b process_scalar32_ld_st

process_scalar32_addcmpbcc:
	/* TODO */
	b panic

process_scalar32_b_bl:
	/* TODO */
	b panic

process_scalar32_ld_st:
	/* TODO */
	b panic

process_scalar48:
	mov r12, 6
	/* TODO: the following might modify r28 */
	and r0, 0xfe00
	cmp r0, 0xe600
	beq process_scalar48_ld_st
	b next_instruction

process_scalar48_ld_st:
	/* TODO */
	b panic

process_vector48:
	mov r12, 6
	/* TODO: vector load/store operations? */
	b next_instruction
process_vector80:
	mov r12, 10
	/* TODO: vector load/store operations? */
	b next_instruction

branch_not_taken:
	b panic
	bl restore_instruction
	mov r12, 0
	b next_instruction

branch_taken:
	bl restore_instruction
	ld r15, branch_target
	mov r14, r15
	b process_instruction

next_instruction:
	/* increment the pointer to the current instruction and continue */
	add r14, r12
	b process_instruction

/**
 * Executes the code until a breakpoint is hit. After a breakpoint is hit, all
 * breakpoints are automatically cleared.
 */
execute:
	/*lea r0, tracer_execute_label
	bl uart_send_str*/
	/*mov r0, r15
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/
	/*mov r0, 0x83fffffc
	ld r0, (r0)*/
	/*mov r0, r15
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r0, r14
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/
	/*mov r0, 0x1*/
	/*bl delay*/
	/* TODO */
	mov r0, 0x83fffffc
	st r15, (r0)
	pop r0-r24
	ld lr, program_lr
	rti

/**
 * Adds a breakpoint at the address specified in r0, and when it is hit, calls
 * the function in r1.
 */
add_first_breakpoint:
	lea r3, first_breakpoint_address
	st r0, (r3)
	lea r3, first_breakpoint_callback
	st r1, (r3)
	/* copy the instruction */
	ldh r2, (r0)
	lea r3, first_breakpoint_backup
	sth r2, (r3)
	/* add "swi 0x1e" */
	mov r1, 0x01de
	sth r1, (r0)
	rts
add_second_breakpoint:
	lea r3, second_breakpoint_address
	st r0, (r3)
	lea r3, second_breakpoint_callback
	st r1, (r3)
	/* copy the instruction */
	ldh r2, (r0)
	lea r3, second_breakpoint_backup
	sth r2, (r3)
	/* add "swi 0x1f" */
	mov r1, 0x01df
	sth r1, (r0)
	rts

/**
 * Handler of the software interrupt 30
 */
first_breakpoint_handler:
	push r0-r24
	st lr, program_lr 

	/*lea r0, tracer_bp1_label
	bl uart_send_str
	mov r0, 0x83fffffc
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/

	lea r0, first_breakpoint_callback
	ld r6, (r0)
	b breakpoint_handler_common

/**
 * Handler of the software interrupt 31
 */
second_breakpoint_handler:
	push r0-r24
	st lr, program_lr

	/*lea r0, tracer_bp2_label
	bl uart_send_str
	mov r0, 0x83fffffc
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str*/

	lea r0, second_breakpoint_callback
	ld r6, (r0)
	b breakpoint_handler_common

breakpoint_handler_common:
	mov r2, 0
	/* restore the instructions which have been overwritten with swi instrs */
restore_breakpoints_loop:
	lea r0, first_breakpoint_callback
	ld r0, (r0, r2)
	cmp r0, -1
	beq no_breakpoint
	lea r0, first_breakpoint_backup
	ldh r0, (r0, r2)
	lea r1, first_breakpoint_address
	ld r1, (r1, r2)
	sth r0, (r1)
no_breakpoint:
	add r2, 1
	bne r2, 2, restore_breakpoints_loop

	/* remove all breakpoint information */
	lea r0, first_breakpoint_address
	mov r1, 0xff
	mov r2, 20
	bl memset

	/* load the address where execution should be resumed */
	mov r0, 0x83fffffc
	ld r15, (r0)
	sub r15, 2
	mov r14, r15
	ldh r13, (r14)
	mov r0, r13

	/* jump into the registered callback */
	b r6

interrupt_handler:
	push r0-r29
	mov r0, 0x83fffff8
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	lea r0, tracer_pc_label
	bl uart_send_str
	mov r0, 0x83fffffc
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r0, 0x83fffffc
	ld r0, (r0)
	ldh r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	lea r0, tracer_interrupt_label
	bl uart_send_str
	lea r0, newline
	bl uart_send_str
	mov r0, 0x7e002000
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r0, r0, r28
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r0, r0, r25
	bl uart_send_int
	lea r0, newline
	bl uart_send_str

	mov r6, 30
	mov r7, 0
interrupt_dump_loop:
	sub r6, 1
	mov r0, r7
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	ld r0, (sp, r6)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	add r7, 1
	bne r6, 0, interrupt_dump_loop
	/* TODO */
interrupt_handler_end:
	b interrupt_handler_end

read_register:
	cmp r0, 24
	bgt read_register_not_pushed
	mul r0, 4
	rsb r0, 0x83fffff4
	ld r0, (r0)
	/*mov r6, r0
	push r6, lr
	lea r0, tracer_debug_label
	bl uart_send_str
	mov r0, r6
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r0, r6
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	
	pop r0, pc*/
	rts
read_register_not_pushed:
	/* TODO */
	b panic

write_register:
	cmp r0, 24
	bgt write_register_not_pushed
	mul r0, 4
	rsb r0, 0x83fffff4
	st r1, (r0)
	rts
write_register_not_pushed:
	/* TODO */
	b panic

emulate_store:
	push r6-r7, lr
	mov r6, r0
	mov r7, r1
	lea r0, tracer_store_label
	bl uart_send_str
	mov r0, r6
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r7
	bl read_register
	mov r7, r0
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	bl uart_flush
	st r7, (r6)
	pop r6-r7, pc

emulate_load:
	push r6-r7, lr
	mov r6, r0
	mov r7, r1
	lea r0, tracer_load_label
	bl uart_send_str
	mov r0, r6
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	ld r6, (r6)
	mov r0, r6
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	mov r1, r6
	mov r0, r7
	bl write_register
	pop r6-r7, pc

save_instruction:
	push r6, lr
	st r14, instruction_backup_source
	st r12, instruction_backup_size
	mov r0, r14
	lea r1, instruction_backup
	mov r2, r12
	bl memcpy
	pop r6, pc

restore_instruction:
	push r6, lr
	lea r0, instruction_backup
	ld r1, instruction_backup_source
	ld r2, instruction_backup_size
	bl memcpy
	pop r6, pc

dump_registers:
	push r6, lr
	lea r0, tracer_dump_label
	bl uart_send_str
	mov r6, 0
dump_registers_loop:
	mov r0, r6
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mul r0, r6, 4
	rsb r0, 0x83fffff4
	ld r0, (r0)
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	add r6, 1
	bne r6, 25, dump_registers_loop
	pop r6, pc

memset:
	add r2, r0
1:
	stb r1, (r0)
	add r0, 1
	bne r0, r2, 1b
	rts

memcpy:
	ldb r3, (r0)
	stb r3, (r1)
	add r0, 1
	add r1, 1
	sub r2, 1
	bne r2, 0, memcpy
	rts

panic:
	lea r0, tracer_panic_label
	bl uart_send_str
	bl dump_registers
1:
	b 1b

	.include "util.inc"

/**
 * Tracer state (stored here outside of interrupt handlers)
 */
	.align 2 
first_breakpoint_address:
	.int -1
second_breakpoint_address:
	.int -1
first_breakpoint_callback:
	.int -1
second_breakpoint_callback:
	.int -1
first_breakpoint_backup:
	.short -1
second_breakpoint_backup:
	.short -1

/**
 * Program state (stored here *in* interrupt handlers)
 */
program_lr:
	.int 0

/**
 * Backup of the modified instruction
 */
instruction_backup_source:
	.int 0
instruction_backup_size:
	.int 0
instruction_backup:
	.short 0
	.short 0
	.short 0

	.align 2
branch_target:
	.int 0

/**
 * Various strings
 */
tracer_bootstring:
	.ascii "tracer\r\n\0"
tracer_pc_label:
	.ascii "pc: \0"
tracer_bp1_label:
	.ascii "bp1: \0"
tracer_bp2_label:
	.ascii "bp2: \0"
tracer_starting:
	.ascii "starting...\r\n\0"
tracer_execute_label:
	.ascii "executing: \0"
tracer_interrupt_label:
	.ascii "interrupt...\r\n\0"
tracer_panic_label:
	.ascii "panic!\r\n\0"
tracer_debug_label:
	.ascii "debug: \0"
tracer_debug2_label:
	.ascii "debug2: \0"
tracer_load_label:
	.ascii "load \0"
tracer_store_label:
	.ascii "store \0"
tracer_dump_label:
	.ascii "register dump: \r\n\0"
space:
	.ascii " \0"
newline:
	.ascii "\r\n\0"

	.align 9
tracer_end:

