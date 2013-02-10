
	.text
execute_scalar32:
	mov r13, 4

	/* addcmpb */
	lsr r0, r14, 12
	beq r0, 0x8, execute_addcmpb
	/* branch */
	mov r0, r14
	and r0, 0xf080
	cmp r0, 0x9000
	beq execute_b_1
	cmp r0, 0x9080
	beq execute_bl_1
	/* ld/st with index */
	lsr r0, r14, 8
	cmp r0, 0xa0
	beq execute_ld_st_index
	/* ld/st with increment/decrement */
	cmp r0, 0xa4
	beq execute_ld_st_decrement
	cmp r0, 0xa5
	beq execute_ld_st_increment
	/* ld/st (unconditional) */
	lsr r0, r14, 9
	cmp r0, 0x51
	beq execute_ld_st_4
	/* ld/st with 16-bit offset */
	lsr r0, r14, 10
	cmp r0, 0x2a
	beq execute_ld_st_o16
	/* mulhd */
	lsr r0, r14, 7
	cmp r0, 0x188
	beq execute_mulhd
	/* div */
	cmp r0, 0x189
	beq execute_div
	/* add shl 8 */
	lsr r0, r14, 5
	cmp r0, 0x62f
	beq execute_add_shl_8
	/* binary op */
	lsr r0, r14, 10
	cmp r0, 0x2c
	beq execute_op_3
	cmp r0, 0x30
	beq execute_op_4
	/* floating point (conversion or binary op) */
	cmp r0, 0x32
	beq execute_float
	/* lea */
	cmp r0, 0x2d
	beq execute_lea_2
	cmp r0, 0x2f
	beq execute_lea_3
	/* TODO: synchronization instructions? (shared register file) */
	lsr r0, r14, 6
	cmp r0, 0x330
	beq execute_test3_mov

	/* unknown instruction */
	bl panic

execute_addcmpb:
	add r0, r15, 2
	ldh r8, (r0)

	/* value to add to rd */
	lsr r0, r14, 4
	and r0, 0xf
	btst r8, 14
	bne add_immediate
	bl load_register
	b 1f
add_immediate:
	exts r0, 3
1:
	mov r7, r0
	/* add the value to rd */
	and r6, r14, 0xf
	mov r0, r6
	bl load_register
	add r7, r0, r7
	mov r1, r7
	mov r0, r6
	bl store_register
	/* load comparison value */
	btst r8, 15
	bne compare_immediate
	lsr r0, r8, 10
	and r0, 0xf
	bl load_register
	b 1f
compare_immediate:
	lsr r0, r8, 8
	and r0, 0x3f
1:
	/* compare */
	cmp r7, r0
	lsr r1, r14, 8
	and r1, 0xf
	lea r2, addcmpbcc_condition_checks
	lsl r1, 2
	add r2, r1
	b r2
addcmpbcc_condition_checks:
	beq addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bne addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	blo addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bhs addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bmi addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bpl addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bvs addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bvc addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bhi addcmpbcc_condition_passed 
	b addcmpbcc_condition_failed
	bls addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bge addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	blt addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bgt addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	ble addcmpbcc_condition_passed 
	b addcmpbcc_condition_failed
	b   addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
	bf  addcmpbcc_condition_passed
	b addcmpbcc_condition_failed
addcmpbcc_condition_passed:
	/* branch */
	btst r8, 15
	extsne r0, r8, 7
	extseq r0, r8, 9
	lsl r0, 1
	ld r1, register_pc
	add r1, r0
	st r1, register_pc
	b execute_instruction
addcmpbcc_condition_failed:
	b next_instruction

execute_b_1:
	/* condition code */
	lsr r0, r14, 8
	and r0, 0xf
	bl check_condition
	/* offset */
	add r0, r15, 2
	ldh r0, (r0)
	exts r1, r14, 6
	lsl r1, 16
	or r0, r1
	lsl r0, 1
	/* add the offset to pc */
	ld r1, register_pc
	add r1, r0
	st r1, register_pc
	b execute_instruction

execute_bl_1:
	/* compute the offset */
	add r0, r15, 2
	ldh r0, (r0)
	extu r1, r14, 7
	lsl r1, 16
	or r0, r1
	lsr r1, r14, 8
	and r1, 0xf
	lsl r1, 23
	or r0, r1
	exts r0, 26
	lsl r0, 1
	/* store the return address */
	ld r1, register_pc
	add r2, r1, 4
	st r2, register_lr
	/* perform the branch */
	add r1, r0
	st r1, register_pc
	bl execute_instruction

execute_ld_st_index:
	add r6, r15, 2
	ldh r6, (r6)
	/* condition code */
	lsr r0, r6, 7
	and r0, 0xf
	bl check_condition
	/* rs */
	lsr r7, r6, 11
	mov r0, r7
	bl load_register
	mov r10, r0
	/* format */
	lsr r8, r14, 6
	and r8, 0x3
	/* size */
	lea r0, format_shift
	ldb r9, (r0, r8)
	/* index */
	btst r6, 6
	bne execute_ld_st_immediate_index
	and r0, r6, 0x1f
	bl load_register
	b execute_ld_st_index_computed
execute_ld_st_immediate_index:
	extu r0, r6, 6
execute_ld_st_index_computed:
	lsl r0, r9
	add r10, r0
	/* rd */
	and r1, r14, 0x1f
	/* load/store bit */
	lsr r3, r14, 5
	and r3, 1
	/* perform the load/store */
	mov r2, r10
	mov r0, r8
	bl load_store
	bl next_instruction

execute_ld_st_increment:
execute_ld_st_decrement:
	add r6, r15, 2
	ldh r6, (r6)
	/* condition code */
	lsr r0, r6, 7
	and r0, 0xf
	bl check_condition
	/* rs */
	lsr r7, r6, 11
	mov r0, r7
	bl load_register
	mov r10, r0
	/* format */
	lsr r8, r14, 6
	and r8, 0x3
	/* size */
	lea r0, format_size
	ldb r9, (r0, r8)
	/* prederement */
	btst r14, 8
	bne no_predecrement
	sub r10, r9
	mov r0, r7
	mov r1, r10
	bl store_register
no_predecrement:
	/* rd */
	and r1, r14, 0x1f
	/* load/store bit */
	lsr r3, r14, 5
	and r3, 1
	/* perform the load/store */
	mov r2, r10
	mov r0, r8
	bl load_store
	/* postincrement */
	btst r14, 8
	beq no_postincrement
	add r10, r9
	mov r0, r7
	mov r1, r10
	bl store_register
no_postincrement:
	bl next_instruction

format_size:
	.byte 4
	.byte 2
	.byte 1
	.byte 2

format_shift:
	.byte 2
	.byte 1
	.byte 0
	.byte 1

execute_ld_st_4:
	add r6, r15, 2
	ldh r6, (r6)
	/* address */
	lsr r0, r6, 11
	and r0, 0x1f
	bl load_register
	extu r2, r6, 11
	lsr r3, r14, 8
	and r3, 1
	lsl r3, 11
	or r2, r3
	exts r2, 11
	add r2, r0
	/* rd */
	and r1, r14, 0x1f
	/* load/store bit */
	lsr r3, r14, 5
	and r3, 1
	/* execute the load/store */
	lsr r0, r14, 6
	and r0, 0x3
	bl load_store
	b next_instruction

execute_ld_st_o16:
	/* base register */
	lsr r0, r14, 8
	and r0, 3
	lea r1, ld_st_o16_base
	ldb r0, (r1, r0)
	bl load_register
	/* offset */
	add r1, r15, 2
	ldsh r1, (r1)
	add r2, r1, r0
	/* rd */
	and r1, r14, 0x1f
	/* format */
	lsr r0, r14, 6
	and r0, 0x3
	/* perform the load/store */
	lsr r3, r14, 5
	and r3, 0x1
	bl load_store
	b next_instruction

ld_st_o16_base:
	.byte 24
	.byte 25
	.byte 31
	.byte 0

execute_mulhd:
	/* TODO */
	bl panic

execute_div:
	add r6, r15, 2
	ldh r6, (r6)
	/* condition */
	lsr r0, r6, 7
	and r0, 0xf
	bl check_condition
	/* a */
	lsr r0, r6, 11
	bl load_register
	mov r7, r0
	/* b */
	btst r6, 6
	bne execute_div_immediate
	and r0, r6, 0x1f
	bl load_register
	b execute_div_common
execute_div_immediate:
	exts r0, r6, 5
execute_div_common:
	/* signed/unsigned? */
	lsr r1, r14, 5
	and r1, 0x3
	mul r1, 6
	lea r2, div_instructions
	add r1, r2
	b r1
div_instructions:
	divs r1, r7, r0
	b div_executed
	divsu r1, r7, r0
	b div_executed
	divus r1, r7, r0
	b div_executed
	divu r1, r7, r0
div_executed:
	/* d */
	and r0, r14, 0x1f
	bl store_register
	bl next_instruction

execute_add_shl_8:
	add r6, r15, 2
	ldh r6, (r6)
	btst r6, 6
	beq 1f
	/* TODO */
	bl panic
1:
	/* condition */
	lsr r0, r6, 7
	and r0, 0xf
	bl check_condition
	/* a */
	lsr r0, r6, 11
	bl load_register
	mov r7, r0
	/* b */
	and r0, r6, 0x1f
	bl load_register
	lsl r0, 8
	add r1, r0, r7
	/* d */
	and r0, r14, 0x1f
	bl store_register
	bl next_instruction


execute_op_3:
	/* b */
	add r3, r15, 2
	ldsh r3, (r3)
	/* ra, rd */
	and r1, r14, 0x1f
	mov r2, r1
	/* op */
	lsr r0, r14, 5
	and r0, 0x1f
	/* execute the binary op */
	bl binary_op
	b next_instruction

execute_op_4:
	add r0, r15, 2
	ldh r5, (r0)
	/* condition code */
	lsr r0, r5, 7
	and r0, 0xf
	bl check_condition
	/* b */
	btst r5, 6
	bne execute_op_4_immediate
	and r0, r5, 0x1f
	bl load_register
	mov r3, r0
	b execute_op_4_common
execute_op_4_immediate:
	exts r3, r5, 5
execute_op_4_common:
	/* ra */
	lsr r2, r5, 11
	/* rd */
	and r1, r14, 0x1f
	/* op */
	lsr r0, r14, 5
	and r0, 0x1f
	/* execute the binary op */
	bl binary_op
	b next_instruction

execute_float:
	/* condition code */
	add r6, r15, 2
	ldh r6, (r6)
	lsr r0, r6, 7
	and r0, 0xf
	bl check_condition
	/* ra */
	lsr r0, r6, 11
	bl load_register
	/* check whether this is actually a conversion, not a binary float op */
	btst r14, 9
	bne execute_float_conv
	mov r7, r0
	/* rd */
	and r8, r14, 0x1f
	/* b */
	btst r6, 6
	bne float_immediate_operand
	and r0, r6, 0x1f
	bl load_register
	b float_operands_read
float_immediate_operand:
	/* sign */
	mov r0, r6
	and r0, 0x20
	lsl r0, 26
	/* exponent */
	and r1, r6, 0x1c
	beq r1, 0, float_operands_read
	/* exponent and mantissa */
	and r1, r6, 0x1f
	add r1, 496 /* actually exponent += 124 */
	lsl r1, 21
	or r0, r1
float_operands_read:
	/* execute the float operation */
	lsr r1, r14, 5
	and r1, 0xf
	mul r1, 6
	lea r2, float_operation_instructions
	add r1, r2
	b r1
float_operation_instructions:
	fadd r1, r7, r0
	b float_store_result
	fsub r1, r7, r0
	b float_store_result
	fmul r1, r7, r0
	b float_store_result
	fdiv r1, r7, r0
	b float_store_result
	fcmp r1, r7, r0
	b float_store_flags
	fabs r1, r7, r0
	b float_store_result
	frsb r1, r7, r0
	b float_store_result
	fmax r1, r7, r0
	b float_store_result
	frcp r1, r7, r0
	b float_store_result
	frsqrt r1, r7, r0
	b float_store_result
	fnmul r1, r7, r0
	b float_store_result
	fmin r1, r7, r0
	b float_store_result
	fld1 r1, r7, r0
	b float_store_result
	fld0 r1, r7, r0
	b float_store_result
	.short 0xc9c1, 0x3f00 /* log2 r1, r7, r0 */
	b float_store_result
	.short 0xc9e1, 0x3f00 /* exp2 r1, r7, r0 */
	/* store the result */
float_store_result:
	mov r0, r8
	bl store_register
	b next_instruction
float_store_flags:
	ld r0, register_sr
	mov r1, r1, sr
	and r1, 0xf
	bic r0, 0xf
	or r0, r1
	st r0, register_sr
	b next_instruction

execute_float_conv:
	mov r1, r0
	/* shift */
	exts r2, r6, 5
	.short 0xca42, 0x1740 /* flts r2, r2 */
	.short 0xc9e2, 0x0702 /* exp2 r2, r0, r2 */
	/* rd */
	and r0, r14, 0x1f
	/* direction */
	lsr r3, r14, 5
	and r3, 0x3
	mul r3, 10
	lea r4, float_conv_instructions
	add r3, r4
	b r3
float_conv_instructions:
	fmul r1, r1, r2
	.short 0xca01, 0x0f40 /* ftrunc r1, r1 */
	b float_conv_done
	fmul r1, r1, r2
	.short 0xca21, 0x0f40 /* floor r1, r1 */
	b float_conv_done
	.short 0xca41, 0x0f40 /* flts r1, r1 */
	fdiv r1, r1, r2
	b float_conv_done
	.short 0xca61, 0x0f40 /* fltu r1, r1 */
	fdiv r1, r1, r2
float_conv_done:
	mov r6, r1
	bl store_register
	b next_instruction

execute_lea_2:
	/* rs */
	lsr r0, r14, 5
	and r0, 0x1f
	bl load_register
	/* offset */
	add r1, r15, 2
	ldsh r1, (r1)
	add r1, r0
	/* rd */
	and r0, r14, 0x1f
	bl store_register
	bl next_instruction

execute_lea_3:
	/* address */
	add r6, r15, 2
	ldsh r6, (r6)
	ld r1, register_pc
	add r1, r6
	/* rd */
	and r0, r14, 0x1f
	bl store_register
	b next_instruction

execute_test3_mov:
	add r6, r15, 2
	ldh r6, (r6)
	lsr r0, r6, 5
	beq r0, 0, 1f
	bl panic
1:
	btst r14, 5
	bne test3_mov_read

test3_mov_write:
	/* read the value to be written */
	and r0, r6, 0x1f
	bl load_register
	/* write the register */
	and r1, r14, 0x1f
	mul r1, 6
	lea r2, test3_mov_write_instructions
	add r1, r2
	lea r2, test3_mov_write_done
	b r1
test3_mov_write_instructions:
	.short 0xcc00, 0x0000
	b r2
	.short 0xcc01, 0x0000
	b r2
	.short 0xcc02, 0x0000
	b r2
	.short 0xcc03, 0x0000
	b r2
	.short 0xcc04, 0x0000
	b r2
	.short 0xcc05, 0x0000
	b r2
	.short 0xcc06, 0x0000
	b r2
	.short 0xcc07, 0x0000
	b r2
	.short 0xcc08, 0x0000
	b r2
	.short 0xcc09, 0x0000
	b r2
	.short 0xcc0a, 0x0000
	b r2
	.short 0xcc0b, 0x0000
	b r2
	.short 0xcc0c, 0x0000
	b r2
	.short 0xcc0d, 0x0000
	b r2
	.short 0xcc0e, 0x0000
	b r2
	.short 0xcc0f, 0x0000
	b r2
	.short 0xcc10, 0x0000
	b r2
	.short 0xcc11, 0x0000
	b r2
	.short 0xcc12, 0x0000
	b r2
	.short 0xcc13, 0x0000
	b r2
	.short 0xcc14, 0x0000
	b r2
	.short 0xcc15, 0x0000
	b r2
	.short 0xcc16, 0x0000
	b r2
	.short 0xcc17, 0x0000
	b r2
	.short 0xcc18, 0x0000
	b r2
	.short 0xcc19, 0x0000
	b r2
	.short 0xcc1a, 0x0000
	b r2
	.short 0xcc1b, 0x0000
	b r2
	.short 0xcc1c, 0x0000
	b r2
	.short 0xcc1d, 0x0000
	b r2
	.short 0xcc1e, 0x0000
	b r2
	.short 0xcc1f, 0x0000
test3_mov_write_done:
	b next_instruction

test3_mov_read:
	/* read the register */
	and r0, r6, 0x1f
	mul r0, 6
	lea r1, test3_mov_read_instructions
	add r0, r1
	lea r2, test3_mov_read_done
	b r0
test3_mov_read_instructions:
	.short 0xcc21, 0x0000
	b r2
	.short 0xcc21, 0x0001
	b r2
	.short 0xcc21, 0x0002
	b r2
	.short 0xcc21, 0x0003
	b r2
	.short 0xcc21, 0x0004
	b r2
	.short 0xcc21, 0x0005
	b r2
	.short 0xcc21, 0x0006
	b r2
	.short 0xcc21, 0x0007
	b r2
	.short 0xcc21, 0x0008
	b r2
	.short 0xcc21, 0x0009
	b r2
	.short 0xcc21, 0x000a
	b r2
	.short 0xcc21, 0x000b
	b r2
	.short 0xcc21, 0x000c
	b r2
	.short 0xcc21, 0x000d
	b r2
	.short 0xcc21, 0x000e
	b r2
	.short 0xcc21, 0x000f
	b r2
	.short 0xcc21, 0x0010
	b r2
	.short 0xcc21, 0x0011
	b r2
	.short 0xcc21, 0x0012
	b r2
	.short 0xcc21, 0x0013
	b r2
	.short 0xcc21, 0x0014
	b r2
	.short 0xcc21, 0x0015
	b r2
	.short 0xcc21, 0x0016
	b r2
	.short 0xcc21, 0x0017
	b r2
	.short 0xcc21, 0x0018
	b r2
	.short 0xcc21, 0x0019
	b r2
	.short 0xcc21, 0x001a
	b r2
	.short 0xcc21, 0x001b
	b r2
	.short 0xcc21, 0x001c
	b r2
	.short 0xcc21, 0x001d
	b r2
	.short 0xcc21, 0x001e
	b r2
	.short 0xcc21, 0x001f
test3_mov_read_done:
	/* store the result */
	and r0, r14, 0x1f
	bl store_register
	b next_instruction

