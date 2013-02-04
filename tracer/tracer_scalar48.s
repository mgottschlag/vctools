
	.text
execute_scalar48:
	mov r13, 6

	/* lea */
	lsr r0, r14, 8
	cmp r0, 0xe5
	beq execute_lea_4
	/* ld/st */
	cmp r0, 0xe6
	beq execute_ld_st_5
	cmp r0, 0xe7
	beq execute_ld_st_6
	/* binary op */
	lsr r0, r14, 10
	beq r0, 0x3a, execute_op_5
	/* add */
	beq r0, 0x3b, execute_add

	/* unknown instruction */
	bl panic

execute_lea_4:
	/* add pc and offset */
	add r0, r15, 2
	ldh r0, (r0)
	add r1, r15, 4
	ldh r1, (r1)
	lsl r1, 16
	or r0, r1
	ld r1, register_pc
	add r1, r0
	/* store result */
	and r0, r14, 0x1f
	bl store_register
	b next_instruction

execute_ld_st_5:
	/* offset */
	add r6, r15, 2
	ldh r7, (r6)
	add r6, r15, 4
	ldh r0, (r6)
	exts r4, r0, 10
	lsl r4, 16
	or r7, r4
	/* base */
	lsr r0, 11
	bl load_register
	add r2, r7, r0
	/* rd */
	and r1, r14, 0x1f
	/* format */
	lsr r0, r14, 6
	and r0, 0x3
	/* load/store */
	lsr r3, r14, 5
	and r3, 1
	/* perform the load/store */
	bl load_store
	b next_instruction

execute_ld_st_6:
	/* offset */
	add r6, r15, 2
	ldh r7, (r6)
	add r6, r15, 4
	ldh r0, (r6)
	exts r4, r0, 10
	lsl r4, 16
	or r7, r4
	/* base */
	lsr r0, 11
	beq r0, 31, 1f
	/* TODO */
	bl panic
1:
	bl load_register
	add r2, r7, r0
	/* rd */
	and r1, r14, 0x1f
	/* format */
	lsr r0, r14, 6
	and r0, 0x3
	/* load/store */
	lsr r3, r14, 5
	and r3, 1
	/* perform the load/store */
	bl load_store
	b next_instruction

execute_op_5:
	/* op */
	lsr r0, r14, 5
	and r0, 31
	/* rd, ra */
	and r1, r14, 31
	mov r2, r1
	/* b */
	add r6, r15, 2
	ldh r3, (r6)
	add r6, r15, 4
	ldh r4, (r6)
	lsl r4, 16
	or r3, r4
	/* execute the binary op */
	bl binary_op
	b next_instruction

execute_add:
	/* a */
	lsr r0, r14, 5
	and r0, 0x1f
	bl load_register
	mov r1, r0
	/* b */
	add r6, r15, 2
	ldh r3, (r6)
	add r6, r15, 4
	ldh r4, (r6)
	lsl r4, 16
	or r3, r4
	/* add the values */
	add r1, r3
	/* rd */
	and r0, r14, 0x1f
	bl store_register
	b next_instruction

