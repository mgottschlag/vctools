
	.text
execute_scalar16:
	mov r13, 2
	/* TODO: this can be optimized using tbb */

	/* nop */
	cmp r14, 0x0001
	beq next_instruction
	/* enable/disable interrupts */
	beq r14, 0x0004, enable_interrupts
	beq r14, 0x0005, disable_interrupts
	/* rti */
	beq r14, 0x000a, execute_rti
	/* swi */
	lsr r0, r14, 5
	beq r0, 0x1, execute_swi_reg
	/* branch */
	lsr r0, r14, 6
	beq r0, 0x1, execute_b_bl_reg
	/* tbb */
	lsr r0, r14, 5
	beq r0, 0x4, execute_tbb
	/* tbh */
	beq r0, 0x5, execute_tbh
	/* cpuid */
	beq r0, 0x7, execute_cpuid
	/* swi */
	lsr r0, r14, 6
	beq r0, 0x7, execute_swi_imm
	/* push/pop */
	lsr r0, r14, 9
	cmp r0, 0x1
	beq execute_push_pop
	/* ld/st */
	lsr r0, r14, 10
	cmp r0, 0x1
	beq execute_ld_st_1
	lsr r0, r14, 11
	cmp r0, 0x1
	beq execute_ld_st_2
	/* lea */
	cmp r0, 0x2
	beq execute_lea
	/* branch */
	cmp r0, 0x3
	beq execute_bcc_imm_1
	/* ld/st */
	lsr r0, r14, 13
	cmp r0, 0x1
	beq execute_ld_st_3
	/* binary ops */
	cmp r0, 0x2
	beq execute_op_1
	cmp r0, 0x3
	beq execute_op_2

	/* unknown instruction */
	bl panic

enable_interrupts:
	ld r0, register_sr
	bset r0, 30
	st r0, register_sr
	bl next_instruction
disable_interrupts:
	ld r0, register_sr
	bclr r0, 30
	st r0, register_sr
	bl next_instruction

execute_rti:
	/* pop sr and pc off the stack */
	mov r0, 25
	bl load_register
	ld r7, (r0)++
	ld r8, (r0)++
	/* write the updated stack pointer */
	mov r1, r0
	mov r0, 25
	bl store_register
	/* store the value of pc and sr
	 * (this has to be done after the store_register above) */
	st r7, register_sr
	st r8, register_pc
	bl execute_instruction

execute_swi_reg:
	/* TODO */
	bl panic

execute_b_bl_reg:
	/* store pc in lr if necessary */
	btst r14, 5
	beq b_bl_no_link
	ld r0, register_pc
	add r0, 2
	st r0, register_lr
b_bl_no_link:
	/* read the register and write the content into pc */
	and r0, r14, 0x1f
	bl load_register
	st r0, register_pc
	b execute_instruction


execute_tbb:
	/* table index */
	and r0, r14, 0x1f
	bl load_register
	/* offset */
	ld r1, register_pc
	add r1, 2
	ldb r0, (r1, r0)
	lsl r0, 1
	add r0, r1
	st r0, register_pc
	bl execute_instruction

execute_tbh:
	/* table index */
	and r0, r14, 0x1f
	bl load_register
	/* offset */
	ld r1, register_pc
	add r1, 2
	ldh r0, (r1, r0)
	lsl r0, 1
	add r0, r1
	st r0, register_pc
	bl execute_instruction

execute_cpuid:
	mov r1, cpuid
	and r0, r14, 31
	bl store_register
	b next_instruction

execute_swi_imm:
	/* switch into interrupt mode */
	ld r6, register_sr
	bclr r0, r6, 29
	st r0, register_sr
	/* fetch the entry from the ivt */
	and r0, r14, 0x1f
	ld r1, interrupt_vector_address
	add r1, 0x80
	lsl r0, 4
	add r0, r1
	ld r7, (r0)
	/* set the supervisor bit if necessary */
	/* TODO: this is totally wrong? */
	btst r7, 0
	beq swi_no_supervisor_bit
	ld r1, register_sr
	bset r1, 29
	st r1, register_sr
swi_no_supervisor_bit:
	/* check that user code cannot call privileged system calls */
	btst r7, 0
	bne swi_unprivileged_interrupt
	/* TODO */
swi_unprivileged_interrupt:
	/* push sr and pc */
	mov r0, 25
	bl load_register
	add r1, r15, 2
	st r1, --(r0)
	st r6, --(r0)
	mov r1, r0
	mov r0, 25
	bl store_register
	/* execute the interrupt handler */
	bclr r7, 0
	st r7, register_pc
	bl execute_instruction

execute_push_pop:
	mov r0, 25
	bl load_register
	mov r10, r0
	/* first register */
	lsr r7, r14, 2
	and r7, 0x18
	cmp r7, 0x8
	moveq r7, r7, 6
	/* push lr/pop pc? */
	mov r8, 0
	btst r14, 8
	movne r8, r8, 1
	/* number of registers to be pushed/popped */
	and r6, r14, 0x1f
	add r6, 1
	andne r6, r6, 0x1f
	cmp r7, 24
bne push_not_r24
	cmp r6, 0x10
	bne push_not_r24
	mov r6, 0
push_not_r24:
	/* push or pop? */
	btst r14, 7
	beq execute_pop

execute_push:
	/* if sp is pushed, then the value *after* the push is pushed */
	mov r11, r10
	add r0, r6, r8
	lsl r0, r0, 2
	sub r11, r0
	/* push lr if necessary */
	bne r8, 1, no_lr_pushed
push_lr:
	ld r0, register_lr
	st r0, --(r10)
no_lr_pushed:
	/* push normal registers */
	mov r9, 0
push_loop:
	beq r9, r6, normal_registers_pushed
	add r0, r9, r7
	and r0, 0x1f
	/* read the register */
	beq r0, 25, push_read_sp
	bl load_register
	b register_read
push_read_sp:
	mov r0, r11
register_read:
	/* push the register */
	st r0, --(r10)
	add r9, 1
	b push_loop
normal_registers_pushed:
	mov r1, r10
	mov r0, 25
	bl store_register
	b next_instruction

execute_pop:
	/* store the value of sp after the pop */
	mov r11, r10
	add r0, r6, r8
	lsl r0, r0, 2
	add r11, r0
	/* pop other registers */
	sub r9, r6, 1
pop_loop:
	cmp r9, -1
	beq all_registers_popped
	add r0, r9, r7
	and r0, 0x1f
	/* pop the register */
	ld r1, (r10)++
	beq r0, 25, pop_sp
	beq r0, 31, single_pop_done
	/* store the value */
	bl store_register
	b single_pop_done
pop_sp:
	mov r11, r1
single_pop_done:
	sub r9, 1
	b pop_loop
all_registers_popped:
	/* pop pc */
	bne r8, 1, no_pc_popped
	ld r0, (r10)++
	st r0, register_pc
no_pc_popped:
	/* set sp to its new value */
	mov r1, r11
	mov r0, 25
	bl store_register
	cmp r8, 1
	bne next_instruction
	b execute_instruction

execute_ld_st_1:
	/* address */
	mov r0, 25
	bl load_register
	lsr r1, r14, 4
	exts r1, 4
	lsl r1, 2
	add r2, r1, r0
	/* rd */
	and r1, r14, 0xf
	/* load/store bit */
	lsr r3, r14, 9
	and r3, 1
	/* execute the load/store */
	mov r0, 0
	bl load_store
	b next_instruction

execute_ld_st_2:
	/* address */
	lsr r0, r14, 4
	and r0, 0xf
	bl load_register
	mov r2, r0
	/* rd */
	and r1, r14, 0xf
	/* load/store bit */
	lsr r3, r14, 8
	and r3, 1
	/* execute the load/store */
	lsr r0, r14, 9
	and r0, 0x3
	bl load_store
	b next_instruction

execute_lea:
	/* sp */
	mov r0, 25
	bl load_register
	/* offset */
	lsr r1, r14, 5
	exts r1, 5
	lsl r1, 2
	add r1, r0
	/* rd */
	and r0, r14, 0x1f
	bl store_register
	b next_instruction

execute_bcc_imm_1:
	/* condition code */
	lsr r0, r14, 7
	and r0, 0xf
	bl check_condition
	/* execute the branch */
	exts r0, r14, 6
	lsl r0, 1
	ld r1, register_pc
	add r1, r0
	st r1, register_pc
	b execute_instruction

execute_ld_st_3:
	/* address */
	lsr r0, r14, 4
	and r0, 0xf
	bl load_register
	lsr r2, r14, 6
	and r2, 0x3c
	add r2, r0
	/* rd */
	and r1, r14, 0xf
	/* load/store bit */
	lsr r3, r14, 12
	and r3, 1
	/* execute the load/store */
	mov r0, 0x0
	bl load_store
	b next_instruction

execute_op_1:
	/* b */
	lsr r0, r14, 4
	and r0, 0xf
	bl load_register
	mov r3, r0
	/* rd, ra */
	and r1, r14, 0xf
	mov r2, r1
	/* op */
	lsr r0, r14, 8
	and r0, 0x1f
	/* execute the binary op */
	bl binary_op
	b next_instruction

execute_op_2:
	/* op */
	lsr r0, r14, 8
	and r0, 0x1e
	/* rd, ra */
	and r1, r14, 0xf
	mov r2, r1
	/* b */
	lsr r3, r14, 4
	and r3, 31
	/* execute the binary op */
	bl binary_op
	b next_instruction

