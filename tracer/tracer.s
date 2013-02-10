
/*
This file implements a memory access tracer which is run on the videocore.
It is placed at 0x84000000 by its bootloader and then copies the program
appended to it to 0x80000000 and starts to execute it at 0x80000200. It dumps
memory accesses and interrupts via the uart.
*/

	.include "vcregs.inc"

	.equ DIRECT_EXEC_START, 0xcf000200
	.equ DIRECT_EXEC_END, 0x0f01bf92

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

	/* the interrupt stack is placed after the ivt */
	lea r0, tracer_end
	add r0, 0x1000
	mov r28, r0, r0

	/* fill the interrupt handler table */
	lea r0, tracer_end
	mov r1, 0x00
	mov r2, 0x200
	bl memset

.macro install_ivt_entry val
	mov r2, \val*4
	add r2, r0
	lea r1, ivt_entry_\val
	st r1, (r2)
.endm

	lea r0, tracer_end
	install_ivt_entry 0x00
	install_ivt_entry 0x01
	install_ivt_entry 0x02
	install_ivt_entry 0x03
	install_ivt_entry 0x04
	install_ivt_entry 0x05
	install_ivt_entry 0x06
	install_ivt_entry 0x07
	install_ivt_entry 0x08
	install_ivt_entry 0x09
	install_ivt_entry 0x0a
	install_ivt_entry 0x0b
	install_ivt_entry 0x0c
	install_ivt_entry 0x0d
	install_ivt_entry 0x0e
	install_ivt_entry 0x0f
	install_ivt_entry 0x10
	install_ivt_entry 0x11
	install_ivt_entry 0x12
	install_ivt_entry 0x13
	install_ivt_entry 0x14
	install_ivt_entry 0x15
	install_ivt_entry 0x16
	install_ivt_entry 0x17
	install_ivt_entry 0x18
	install_ivt_entry 0x19
	install_ivt_entry 0x1a
	install_ivt_entry 0x1b
	install_ivt_entry 0x1c
	install_ivt_entry 0x1d
	install_ivt_entry 0x1e
	install_ivt_entry 0x1f
	install_ivt_entry 0x40
	install_ivt_entry 0x41
	install_ivt_entry 0x42
	install_ivt_entry 0x43
	install_ivt_entry 0x44
	install_ivt_entry 0x45
	install_ivt_entry 0x46
	install_ivt_entry 0x47
	install_ivt_entry 0x48
	install_ivt_entry 0x49
	install_ivt_entry 0x4a
	install_ivt_entry 0x4b
	install_ivt_entry 0x4c
	install_ivt_entry 0x4d
	install_ivt_entry 0x4e
	install_ivt_entry 0x4f
	install_ivt_entry 0x50
	install_ivt_entry 0x51
	install_ivt_entry 0x52
	install_ivt_entry 0x53
	install_ivt_entry 0x54
	install_ivt_entry 0x55
	install_ivt_entry 0x56
	install_ivt_entry 0x57
	install_ivt_entry 0x58
	install_ivt_entry 0x59
	install_ivt_entry 0x5a
	install_ivt_entry 0x5b
	install_ivt_entry 0x5c
	install_ivt_entry 0x5d
	install_ivt_entry 0x5e
	install_ivt_entry 0x5f
	install_ivt_entry 0x60
	install_ivt_entry 0x61
	install_ivt_entry 0x62
	install_ivt_entry 0x63
	install_ivt_entry 0x64
	install_ivt_entry 0x65
	install_ivt_entry 0x66
	install_ivt_entry 0x67
	install_ivt_entry 0x68
	install_ivt_entry 0x69
	install_ivt_entry 0x6a
	install_ivt_entry 0x6b
	install_ivt_entry 0x6c
	install_ivt_entry 0x6d
	install_ivt_entry 0x6e
	install_ivt_entry 0x6f
	install_ivt_entry 0x70
	install_ivt_entry 0x71
	install_ivt_entry 0x72
	install_ivt_entry 0x73
	install_ivt_entry 0x74
	install_ivt_entry 0x75
	install_ivt_entry 0x76
	install_ivt_entry 0x77
	install_ivt_entry 0x78
	install_ivt_entry 0x79
	install_ivt_entry 0x7a
	install_ivt_entry 0x7b
	install_ivt_entry 0x7c
	install_ivt_entry 0x7d
	install_ivt_entry 0x7e
	install_ivt_entry 0x7f

	/* install the interrupt handlers */
	lea r0, tracer_end
	mov r1, 0x7e002030
	st r0, (r1)
	/* start executing the code */
	lea r0, starting_label
	bl uart_send_str


execute_instruction:
	/* TODO: enable/disable interrupts? */
	ld r0, register_sr
	btst r0, 30
	beq interrupts_disabled
	.short 0x0004
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	.short 0x0005
interrupts_disabled:
	/* load the current instruction */
	ld r15, register_pc
	ldh r14, (r15)

	/*lsr r0, r15, 28
	beq r0, 0x8, no_debug_output
	cmp r15, 0x0f046b5e
	beq no_debug_output
	cmp r15, 0x0f046b62
	beq no_debug_output
debug_output:
	mov r12, 0
	lea r0, execute_label
	bl uart_send_str
	mov r0, r15
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r14
	bl uart_send_int_newline
no_debug_output:*/

	/*cmp r15, DIRECT_EXEC_START
	beq direct_execution*/
	cmp r15, DIRECT_EXEC_END
	bne 1f
	bl dump_registers
1:

	/* decode the size of the instruction */
	btst r14, 15
	beq execute_scalar16
	btst r14, 14
	beq execute_scalar32
	btst r14, 13
	beq execute_scalar32
	btst r14, 12
	beq execute_scalar48
	btst r14, 11
	beq execute_vector48
	b execute_vector80

.include "tracer_scalar16.s"
.include "tracer_scalar32.s"
.include "tracer_scalar48.s"
/*.include "tracer_vector.s"*/

execute_vector48:
	/* TODO */
	bl panic

execute_vector80:
	/* TODO */
	bl panic

next_instruction:
	/* add the size of the instruction to pc */
	add r15, r13
	st r15, register_pc
	b execute_instruction

/**
 * binary integer operation
 * r0: op
 * r1: rd
 * r2: ra
 * r3: b
 */
binary_op:
	push r6-r7, lr
	mov r7, r1
	/* calculate the address of the instruction */
	lea r5, binary_op_instructions
	lsl r0, 2
	add r5, r0
	/* load the first argument */
	mov r0, r2
	bl load_register
	mov r2, r0
	/* execute the binary op */
	lea r4, binary_op_executed
	lea r6, binary_op_store_flags
	b r5
binary_op_instructions:
	mov    r2, r3
	b r4
	cmn    r2, r3
	b r6
	add    r2, r3
	b r4
	bic    r2, r3
	b r4
	mul    r2, r3
	b r4
	eor    r2, r3
	b r4
	sub    r2, r3
	b r4
	and    r2, r3
	b r4
	mvn    r2, r3
	b r4
	ror    r2, r3
	b r4
	cmp    r2, r3
	b r6
	rsb    r2, r3
	b r4
	btst   r2, r3
	/* TODO: does btst erase all other flags? */
	b r6
	or     r2, r3
	b r4
	extu   r2, r3
	b r4
	max    r2, r3
	b r4
	bset   r2, r3
	b r4
	min    r2, r3
	b r4
	bclr   r2, r3
	b r4
	adds2  r2, r3
	b r4
	bchg   r2, r3
	b r4
	adds4  r2, r3
	b r4
	adds8  r2, r3
	b r4
	adds16 r2, r3
	b r4
	exts   r2, r3
	b r4
	neg    r2, r3
	b r4
	lsr    r2, r3
	b r4
	clz    r2, r3
	b r4
	lsl    r2, r3
	b r4
	brev   r2, r3
	b r4
	asr    r2, r3
	b r4
	abs    r2, r3
	b r4
binary_op_executed:
	/* store the result */
	mov r0, r7
	mov r1, r2
	bl store_register
	pop r6-r7, pc
binary_op_store_flags:
	ld r0, register_sr
	mov r1, r1, sr
	and r1, 0xf
	bic r0, 0xf
	or r0, r1
	st r0, register_sr
	pop r6-r7, pc

/**
 * load/store operation
 * r0: format
 * r1: rd
 * r2: address
 * r3: load/store
 */
load_store:
	push r6-r8, lr
	/* early dram initialization and reclocking registers are emulated */
emulate_load_store_branch:
	ld r4, register_emulation_enabled
	cmp r4, 1
	beq emulate_load_store
load_store_no_emulation:
	mov r7, r2
	mov r8, r0
	cmp r3, 1
	beq store
load:
	/* execute the load */
	lea r5, load_instructions
	lsl r0, 2
	add r5, r0
	b r5
load_instructions:
	ld r6, (r2)
	b load_executed
	ldh r6, (r2)
	b load_executed
	ldb r6, (r2)
	b load_executed
	ldsh r6, (r2)
	b load_executed
load_executed:
	/* store the result */
	mov r0, r1
	mov r1, r6
	bl store_register
	/* hide sd card data spam */
	ld r0, register_pc
	cmp r0, 0x80001a74
	beq load_skip_output
	cmp r0, 0x80001a7a
	beq load_skip_output
	cmp r0, 0x80001a86
	beq load_skip_output
	cmp r0, 0x80001a94
	beq load_skip_output
	/* hide copying start.elf to high memory */
	cmp r0, 0x800018c2
	beq load_skip_output
	/* dump the load data */
	lea r0, load_label
	bl uart_send_str
	add r0, r8, '0'
	bl uart_send_char
	ld r0, register_pc
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r7
	bl uart_send_int
	mov r0, r6
	bl uart_send_int_newline
load_skip_output:
	pop r6-r8, pc
store:
	/* fetch the data */
	mov r0, r1
	bl load_register
	mov r6, r0
	/* hide sd card data spam */
	ld r0, register_pc
	cmp r0, 0x80001a9a
	beq store_skip_output
	/* hide copying start.elf to high memory */
	cmp r0, 0x800018c6
	beq store_skip_output
	/* hide start.elf clearing .bss */
	cmp r0, 0x0f046b5e
	beq store_skip_output
	/* dump the store data */
	lea r0, store_label
	bl uart_send_str
	add r0, r8, '0'
	bl uart_send_char
	ld r0, register_pc
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r7
	bl uart_send_int
	mov r0, r6
	bl uart_send_int_newline
store_skip_output:
	/* intercept writes to the interrupt vector register */
	cmp r7, 0x7e002030
	bne 1f
	st r6, interrupt_vector_address
	pop r6-r8, pc
1:
	/* execute the store */
	lea r5, store_instructions
	lsl r0, r8, 2
	add r5, r0
	b r5
store_instructions:
	st r6, (r7)
	b store_executed
	sth r6, (r7)
	b store_executed
	stb r6, (r7)
	b store_executed
	stsh r6, (r7)
	b store_executed
store_executed:
	pop r6-r8, pc

/**
 * checks the condition in r0 and calls next_instruction if it fails
 * r0: condition
 */
check_condition:
	/* load the status flags */
	mov r1, r1, sr
	ld r2, register_sr
	bic r1, 0xf
	and r2, 0xf
	or r1, r2
	mov sr, r1, r1
	/* execute the condition check */
	lea r1, condition_checks
	lsl r0, 2
	add r1, r0
	b r1
condition_checks:
	beq condition_passed
	b condition_failed
	bne condition_passed
	b condition_failed
	blo condition_passed
	b condition_failed
	bhs condition_passed
	b condition_failed
	bmi condition_passed
	b condition_failed
	bpl condition_passed
	b condition_failed
	bvs condition_passed
	b condition_failed
	bvc condition_passed
	b condition_failed
	bhi condition_passed 
	b condition_failed
	bls condition_passed
	b condition_failed
	bge condition_passed
	b condition_failed
	blt condition_passed
	b condition_failed
	bgt condition_passed
	b condition_failed
	ble condition_passed 
	b condition_failed
	b   condition_passed
	b condition_failed
	bf  condition_passed
	b condition_failed
condition_passed:
	rts
condition_failed:
	b next_instruction

/**
 * loads the register addressed by r0 and returns the value in r0
 */
load_register:
	push r6, lr
	beq r0, 25, load_sp
	lea r6, registers
	ld r0, (r6, r0)
	pop r6, pc
load_sp:
	/* r25/r28, depending on the mode */
	ld r6, register_sr
	btst r6, 30
	bne load_r28
	ld r0, register_sp
	pop r6, pc
load_r28:
	ld r0, register_r28
	pop r6, pc

/**
 * stores the value in r1 into the register addressed by r0
 */
store_register:
	push r6, lr
	beq r0, 25, store_sp
	lea r6, registers
	st r1, (r6, r0)
	pop r6, pc
store_sp:
	/* r25/r28, depending on the mode */
	ld r6, register_sr
	btst r6, 30
	bne store_r28
	st r1, register_sp
	pop r6, pc
store_r28:
	st r1, register_r28
	pop r6, pc

	.include "tracer_load_store_emul.s"

/* auxiliary functions */
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

uart_send_int_newline:
	push r6, lr
	bl uart_send_int
	lea r0, newline
	bl uart_send_str
	pop r6, pc

panic:
	mov r6, r0, lr
	lea r0, panic_label
	bl uart_send_str
	mov r0, r14
	bl uart_send_int_newline
	mov r0, r6
	bl uart_send_int_newline
	bl dump_registers
1:
	b 1b

interrupt_handler_common:
	lea r0, interrupt_label
	bl uart_send_str
	mov r0, r6
	bl uart_send_int_newline
	/* save the old values of pc and sr */
	ld r7, register_pc
	ld r8, register_sr
	/* update pc and sr to enter the interrupt handler */
	ld r0, interrupt_vector_address
	ld r0, (r0, r6)
	bl uart_send_int_newline
	ld r0, interrupt_vector_address
	ld r0, (r0, r6)
	st r0, register_pc
	ld r0, register_sr
	extu r0, 29
	st r0, register_sr
	/* push pc and sr onto the emulated stack */
	mov r0, 25
	bl load_register
	st r7, --(r0)
	st r8, --(r0)
	mov r1, r0
	mov r0, 25
	bl store_register
	/* continue emulation */
	pop r0
	bclr r0, 30
	push r0
	rti

exception_handler_common:
	push r0
	lea r0, exception_label
	bl uart_send_str
	pop r0
	bl uart_send_int_newline
	mov r6, 30
1:
	sub r6, 1
	mov r0, r6
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	pop r0
	bl uart_send_int_newline
	bne r6, 0, 1b
	lea r0, label_sr
	bl uart_send_str
	pop r0
	bl uart_send_int_newline
	lea r0, label_pc
	bl uart_send_str
	pop r0
	bl uart_send_int_newline
	bl panic

dump_registers:
	push r6, lr
	lea r0, dump_label
	bl uart_send_str
	mov r6, 0
1:
	mov r0, r6
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	lea r0, registers
	ld r0, (r0, r6)
	bl uart_send_int_newline
	add r6, 1
	bne r6, 0x20, 1b
	pop r6, pc

	.include "util.inc"

	.align 1
.macro ivt_exception_entry val
ivt_entry_\val:
	push r0-r29
	mov r0, \val
	b exception_handler_common
.endm

ivt_exception_entry 0x00
ivt_exception_entry 0x01
ivt_exception_entry 0x02
ivt_exception_entry 0x03
ivt_exception_entry 0x04
ivt_exception_entry 0x05
ivt_exception_entry 0x06
ivt_exception_entry 0x07
ivt_exception_entry 0x08
ivt_exception_entry 0x09
ivt_exception_entry 0x0a
ivt_exception_entry 0x0b
ivt_exception_entry 0x0c
ivt_exception_entry 0x0d
ivt_exception_entry 0x0e
ivt_exception_entry 0x0f
ivt_exception_entry 0x10
ivt_exception_entry 0x11
ivt_exception_entry 0x12
ivt_exception_entry 0x13
ivt_exception_entry 0x14
ivt_exception_entry 0x15
ivt_exception_entry 0x16
ivt_exception_entry 0x17
ivt_exception_entry 0x18
ivt_exception_entry 0x19
ivt_exception_entry 0x1a
ivt_exception_entry 0x1b
ivt_exception_entry 0x1c
ivt_exception_entry 0x1d
ivt_exception_entry 0x1e
ivt_exception_entry 0x1f

.macro ivt_interrupt_entry val
ivt_entry_\val:
	mov r6, \val
	b interrupt_handler_common
.endm

ivt_interrupt_entry 0x40
ivt_interrupt_entry 0x41
ivt_interrupt_entry 0x42
ivt_interrupt_entry 0x43
ivt_interrupt_entry 0x44
ivt_interrupt_entry 0x45
ivt_interrupt_entry 0x46
ivt_interrupt_entry 0x47
ivt_interrupt_entry 0x48
ivt_interrupt_entry 0x49
ivt_interrupt_entry 0x4a
ivt_interrupt_entry 0x4b
ivt_interrupt_entry 0x4c
ivt_interrupt_entry 0x4d
ivt_interrupt_entry 0x4e
ivt_interrupt_entry 0x4f
ivt_interrupt_entry 0x50
ivt_interrupt_entry 0x51
ivt_interrupt_entry 0x52
ivt_interrupt_entry 0x53
ivt_interrupt_entry 0x54
ivt_interrupt_entry 0x55
ivt_interrupt_entry 0x56
ivt_interrupt_entry 0x57
ivt_interrupt_entry 0x58
ivt_interrupt_entry 0x59
ivt_interrupt_entry 0x5a
ivt_interrupt_entry 0x5b
ivt_interrupt_entry 0x5c
ivt_interrupt_entry 0x5d
ivt_interrupt_entry 0x5e
ivt_interrupt_entry 0x5f
ivt_interrupt_entry 0x60
ivt_interrupt_entry 0x61
ivt_interrupt_entry 0x62
ivt_interrupt_entry 0x63
ivt_interrupt_entry 0x64
ivt_interrupt_entry 0x65
ivt_interrupt_entry 0x66
ivt_interrupt_entry 0x67
ivt_interrupt_entry 0x68
ivt_interrupt_entry 0x69
ivt_interrupt_entry 0x6a
ivt_interrupt_entry 0x6b
ivt_interrupt_entry 0x6c
ivt_interrupt_entry 0x6d
ivt_interrupt_entry 0x6e
ivt_interrupt_entry 0x6f
ivt_interrupt_entry 0x70
ivt_interrupt_entry 0x71
ivt_interrupt_entry 0x72
ivt_interrupt_entry 0x73
ivt_interrupt_entry 0x74
ivt_interrupt_entry 0x75
ivt_interrupt_entry 0x76
ivt_interrupt_entry 0x77
ivt_interrupt_entry 0x78
ivt_interrupt_entry 0x79
ivt_interrupt_entry 0x7a
ivt_interrupt_entry 0x7b
ivt_interrupt_entry 0x7c
ivt_interrupt_entry 0x7d
ivt_interrupt_entry 0x7e
ivt_interrupt_entry 0x7f

direct_execution:
	lea r0, reenter_tracer_code
	st r0, reenter_address
	lea r0, reenter_tracer
	mov r1, DIRECT_EXEC_END
	mov r2, 10
	bl memcpy

	mov r0, 0x83000000
	ld r1, register_pc
	st r1, --(r0)
	ld r1, register_sr
	st r1, --(r0)

	lea sp, registers
	ld r0, (sp)++
	ld r1, (sp)++
	ld r2, (sp)++
	ld r3, (sp)++
	ld r4, (sp)++
	ld r5, (sp)++
	ld r6, (sp)++
	ld r7, (sp)++
	ld r8, (sp)++
	ld r9, (sp)++
	ld r10, (sp)++
	ld r11, (sp)++
	ld r12, (sp)++
	ld r13, (sp)++
	ld r14, (sp)++
	ld r15, (sp)++
	ld r16, (sp)++
	ld r17, (sp)++
	ld r18, (sp)++
	ld r19, (sp)++
	ld r20, (sp)++
	ld r21, (sp)++
	ld r22, (sp)++
	ld r23, (sp)++
	ld r24, (sp)++
	add sp, 4
	ld r26, (sp)++
	ld r27, (sp)++
	add sp, 4
	ld r29, (sp)++
	sub sp, 20
	mov sp, 0x82fffff8
	rti

reenter_tracer_code:
	mov r1, r0, sp
	mov sp, 0x84000000
	lea r0, registers
	mov r2, 0
	mov r3, 31
1:
	ld r4, (r1, r2)
	st r4, (r0, r3)
	add r2, 1
	sub r3, 1
	bne r2, 32, 1b
	bl dump_registers
1:
	b 1b

	.align 2
reenter_tracer:
	push r0-r31
	.short 0xe800 /* mov r0, address */
reenter_address:
	.int 0
	bl r0

	.align 2
registers:
	.int 0x80000200
	.int 0xffffffff
	.int 0x7ee02000
	.int 0x20000008
	.int 0x00000000
	.int 0x7e200080
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x00000001
	.int 0x00000000
	.int 0x000010c0
	.int 0x00000000
	.int 0x7e000080
	.int 0x0001ef40
	.int 0x80000000
	.int 0x60008124
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x00000000
	.int 0x60008000 /* cb - base pointer */
register_sp:
	.int 0x6000865c /* sp - stack pointer */
register_lr:
	.int 0x60003602 /* lr - link register */
	.int 0x00000000
register_r28:
	.int 0x00000000 /* ssp */
	.int 0x00000000
register_sr:
	.int 0x2000000a /* sr - status register */
register_pc:
	.int 0x80000200
registers_end:

interrupt_vector_address:
	.int 0x0

register_emulation_enabled:
	.int 1

/**
 * Various strings
 */
starting_label:
	.ascii "starting...\n\0"
execute_label:
label_pc:
	.ascii "pc: \0"
label_sr:
	.ascii "sr: \0"
panic_label:
	.ascii "panic!\n\0"
interrupt_label:
	.ascii "interrupt: \0"
exception_label:
	.ascii "exception: \0"
load_label:
	.ascii "r\0"
store_label:
	.ascii "w\0"
dump_label:
	.ascii "register dump: \n\0"
space:
	.ascii " \0"
newline:
	.ascii "\n\0"

	.align 9
tracer_end:

