
execute_vector:
	/* save the emulator state */
	push r0-r29, lr
	st sp, vector_tracer_sp
	/* load the emulated state */
	/* TODO */
	/* execute the instruction (patched into the following bytes) */
vector_instr:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	/* save the emulated state */
	/* TODO */
	/* restore the emulator state */
	ld sp, vector_tracer_sp
	pop r0-r29, pc

	.align 2
vector_tracer_sp:
	.int 0
